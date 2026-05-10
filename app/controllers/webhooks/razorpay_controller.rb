# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

module Webhooks
  class RazorpayController < ActionController::Base
    skip_forgery_protection

    RAZORPAY_HOST = "api.razorpay.com"

    # Legacy path when +callback_url+ was omitted from Payment Link creation; also accepts
    # redirects that only hit +/webhooks/razorpay+.
    def payment_callback
      if params[:razorpay_payment_link_id].present?
        advance_callback
      else
        head :ok
      end
    rescue StandardError => e
      Rails.logger.error { "Razorpay payment_callback error: #{e.class}: #{e.message}" }
      head :ok
    end

    # Browser redirect after buyer pays via a Razorpay Payment Link (+callback_method+ get).
    def advance_callback
      process_payment_link_redirect
    rescue StandardError => e
      Rails.logger.error { "Razorpay advance_callback error: #{e.class}: #{e.message}" }
      redirect_after_payment(:alert, "Something went wrong processing your payment. If you were charged, please contact support.")
    end

    # Dashboard webhook (POST JSON). Configure URL: +POST /webhooks/razorpay/notify+
    # Subscribe to +payment_link.paid+ (and optionally other link events). Secret:
    # +Rails.application.credentials.dig(:razorpay, :webhook_secret)+
    def receive
      raw_body = read_webhook_raw_body
      signature = webhook_signature_header

      webhook_secret = Rails.application.credentials.dig(:razorpay, :webhook_secret).to_s
      if webhook_secret.blank?
        Rails.logger.error("Razorpay webhook: credentials razorpay.webhook_secret is blank")
        return head :service_unavailable
      end

      unless valid_razorpay_webhook_signature?(raw_body, signature, secret: webhook_secret)
        Rails.logger.warn("Razorpay webhook: invalid X-Razorpay-Signature")
        return head :unauthorized
      end

      payload = JSON.parse(raw_body)
      event = payload["event"].to_s

      case event
      when "payment_link.paid"
        handle_payment_link_paid_webhook(payload)
      when "payment_link.partially_paid"
        Rails.logger.info("Razorpay webhook: payment_link.partially_paid acknowledged (not applied)")
        head :ok
      else
        head :ok
      end
    rescue JSON::ParserError => e
      Rails.logger.warn("Razorpay webhook: JSON parse error #{e.message}")
      head :bad_request
    rescue StandardError => e
      Rails.logger.error("Razorpay webhook receive error: #{e.class}: #{e.message}")
      head :internal_server_error
    end

    def shipping_callback
      Rails.logger.info { "Razorpay shipping callback ignored after orders table cleanup" }
      head :ok

    rescue StandardError => e
      Rails.logger.error { "Razorpay shipping_callback error: #{e.class}: #{e.message}" }
      head :ok
    end

    private

    def process_payment_link_redirect
      link_id = params[:razorpay_payment_link_id].to_s.presence
      ref_id = params[:razorpay_payment_link_reference_id].to_s.presence
      status = params[:razorpay_payment_link_status].to_s.presence
      payment_id = params[:razorpay_payment_id].to_s.presence
      signature = params[:razorpay_signature].to_s.presence

      unless [ link_id, ref_id, status, payment_id, signature ].all?(&:present?)
        Rails.logger.warn("Razorpay payment link redirect: missing query params")
        return redirect_after_payment(:alert, "Missing payment information.")
      end

      unless valid_payment_link_redirect_signature?(link_id, ref_id, status, payment_id, signature)
        Rails.logger.warn("Razorpay payment link redirect: invalid signature link_id=#{link_id}")
        return redirect_after_payment(:alert, "Could not verify payment.")
      end

      unless status == "paid"
        Rails.logger.info("Razorpay payment link redirect: status=#{status} (no-op)")
        return redirect_after_payment(:notice, "Payment was not completed.")
      end

      result = apply_paid_payment_link(link_id: link_id, payment_id: payment_id, amount_rupees: nil, source: "redirect")
      respond_redirect_from_apply_result(result)
    end

    # +amount_rupees+ — from webhook payment entity (paise→rupees) or +nil+ to resolve via API / stored amounts.
    def apply_paid_payment_link(link_id:, payment_id:, amount_rupees:, source:)
      advance = OrderAdvancePayment.find_by(razorpay_payment_link_id: link_id)
      unless advance
        Rails.logger.warn("Razorpay #{source}: unknown link_id=#{link_id}")
        return { ok: false, message: "We could not match this payment to an order.", log: "unknown_link" }
      end

      order = advance.order
      resolved_amount = amount_rupees
      resolved_amount ||= fetch_payment_amount_rupees(payment_id)
      if resolved_amount.nil?
        resolved_amount = order.full_prepaid? ? order.amount.to_d : advance.amount.to_d
        Rails.logger.warn("Razorpay #{source}: amount API failed, using stored amount order=#{order.id}")
      end

      if order.full_prepaid?
        paid_paise = (resolved_amount * 100).round
        total_paise = (order.amount * 100).round
        if paid_paise < total_paise
          Rails.logger.warn("Razorpay #{source}: underpaid order=#{order.id} paid=#{resolved_amount} expected=#{order.amount}")
          return { ok: false, message: "The payment amount does not match the order total.", log: "underpaid" }
        end

        outcome = ApplicationRecord.transaction do
          unless advance.paid?
            advance.update!(razorpay_payment_id: payment_id, paid_at: Time.current)
          end
          result = Orders::ProcessPaymentResult.execute(
            order_id: order.id,
            amount_paid: resolved_amount,
            razorpay_payment_id: payment_id
          )
          raise ActiveRecord::Rollback unless result.success?

          result
        end

        if outcome.nil?
          Rails.logger.error("Razorpay #{source}: ProcessPaymentResult failed after rollback order=#{order.id}")
          return {
            ok: false,
            message: "We could not apply your payment to the order. If you were charged, please contact support.",
            log: "prepaid_failed"
          }
        end

        { ok: true, message: "Thank you. Your payment was received." }
      else
        paid_paise = (resolved_amount * 100).round
        expected_paise = (advance.amount * 100).round
        if (paid_paise - expected_paise).abs > 1
          Rails.logger.warn("Razorpay #{source}: amount mismatch order=#{order.id} paid=#{resolved_amount} expected=#{advance.amount}")
          return { ok: false, message: "The payment amount does not match the requested advance.", log: "amount_mismatch" }
        end

        outcome = Orders::ProcessAdvancePayment.execute(order: order, razorpay_payment_id: payment_id)
        unless outcome.success?
          Rails.logger.error("Razorpay #{source}: ProcessAdvancePayment failed order=#{order.id} errors=#{outcome.errors}")
          return {
            ok: false,
            message: "We could not record your advance payment. If you were charged, please contact support.",
            log: "advance_failed"
          }
        end

        { ok: true, message: "Thank you. Your advance payment was received." }
      end
    end

    def respond_redirect_from_apply_result(result)
      if result[:ok]
        redirect_after_payment(:notice, result[:message])
      else
        redirect_after_payment(:alert, result[:message])
      end
    end

    def handle_payment_link_paid_webhook(payload)
      link_id = payload.dig("payload", "payment_link", "entity", "id").to_s.presence
      payment_entity = payload.dig("payload", "payment", "entity")
      payment_id = payment_entity&.dig("id").to_s.presence
      amount_paise = payment_entity&.dig("amount")
      amount_rupees =
        if amount_paise.nil?
          nil
        else
          BigDecimal(amount_paise.to_s) / 100
        end

      if link_id.blank? || payment_id.blank?
        Rails.logger.warn("Razorpay webhook payment_link.paid: missing link_id or payment_id")
        return head :ok
      end

      result = apply_paid_payment_link(link_id: link_id, payment_id: payment_id, amount_rupees: amount_rupees, source: "webhook")
      if result[:ok]
        Rails.logger.info("Razorpay webhook payment_link.paid applied link_id=#{link_id} payment_id=#{payment_id}")
      else
        Rails.logger.error("Razorpay webhook payment_link.paid not applied link_id=#{link_id} reason=#{result[:log]} message=#{result[:message]}")
      end

      head :ok
    end

    def read_webhook_raw_body
      if request.body.respond_to?(:rewind)
        request.body.rewind
        body = request.body.read
        request.body.rewind
        return body if body.present?
      end

      request.raw_post.to_s
    end

    def webhook_signature_header
      request.headers["HTTP_X_RAZORPAY_SIGNATURE"].presence ||
        request.headers["X-Razorpay-Signature"].presence
    end

    def valid_razorpay_webhook_signature?(raw_body, signature, secret:)
      return false if signature.blank? || raw_body.blank?

      expected = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, raw_body)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    def redirect_after_payment(flash_key, message)
      url = app_public_root_url
      opts = {}
      opts[:notice] = message if flash_key == :notice
      opts[:alert] = message if flash_key == :alert

      if url == "/"
        redirect_to url, **opts
      else
        redirect_to url, allow_other_host: true, **opts
      end
    end

    def app_public_root_url
      domain = Rails.application.credentials.dig(:app, :domain).to_s
      return "/" if domain.blank?

      base = domain.start_with?("http://", "https://") ? domain : "https://#{domain}"
      "#{base.chomp('/')}/"
    end

    def valid_payment_link_redirect_signature?(link_id, reference_id, link_status, payment_id, signature)
      return false if signature.blank?

      secret = Rails.application.credentials.dig(:razorpay, :key_secret).to_s
      return false if secret.blank?

      payload = "#{link_id}|#{reference_id}|#{link_status}|#{payment_id}"
      expected = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    def fetch_payment_amount_rupees(payment_id)
      return nil if payment_id.blank?

      key_id = Rails.application.credentials.dig(:razorpay, :key_id)
      key_secret = Rails.application.credentials.dig(:razorpay, :key_secret)
      return nil if key_id.blank? || key_secret.blank?

      uri = URI::HTTPS.build(host: RAZORPAY_HOST, path: "/v1/payments/#{CGI.escape(payment_id)}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 15
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Basic #{Base64.strict_encode64("#{key_id}:#{key_secret}")}"

      response = http.request(request)
      return nil unless response.code.to_i == 200

      body = JSON.parse(response.body)
      paise = body["amount"]
      return nil if paise.nil?

      BigDecimal(paise.to_s) / 100
    rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError
      nil
    end

    def respond_shipping_callback(order:, notice:, alert:); end
  end
end
