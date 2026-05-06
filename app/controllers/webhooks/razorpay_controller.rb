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

    def payment_callback
      link_id = params[:razorpay_payment_link_id].to_s
      reference_id = params[:razorpay_payment_link_reference_id].to_s
      link_status = params[:razorpay_payment_link_status].to_s
      payment_id = params[:razorpay_payment_id].to_s
      signature = params[:razorpay_signature].to_s

      unless valid_razorpay_signature?(link_id, reference_id, link_status, payment_id, signature)
        Rails.logger.warn { "Razorpay callback signature invalid for payment_link #{link_id}" }
        head :bad_request
        return
      end

      if link_status == "paid"
        order = Order.find_by(razorpay_payment_link_id: link_id)
        if order.blank?
          Rails.logger.warn { "Razorpay callback: no order for payment_link_id #{link_id}" }
          head :ok
          return
        end

        amount_rupees = fetch_payment_amount_rupees(payment_id)
        if amount_rupees.nil?
          Rails.logger.error { "Razorpay callback: could not fetch payment #{payment_id}" }
          head :ok
          return
        end

        Orders::ProcessPaymentResult.execute(
          order_id: order.id,
          amount_paid: amount_rupees,
          razorpay_payment_id: payment_id
        )
      else
        Rails.logger.info { "Razorpay callback status=#{link_status} for link #{link_id}" }
      end

      head :ok
    rescue StandardError => e
      Rails.logger.error { "Razorpay payment_callback error: #{e.class}: #{e.message}" }
      head :ok
    end

    def shipping_callback
      link_id = params[:razorpay_payment_link_id].to_s
      reference_id = params[:razorpay_payment_link_reference_id].to_s
      link_status = params[:razorpay_payment_link_status].to_s
      payment_id = params[:razorpay_payment_id].to_s
      signature = params[:razorpay_signature].to_s

      order = Order.find_by(shipping_payment_link_id: link_id)
      if order.blank?
        Rails.logger.warn { "Razorpay shipping_callback: no order for shipping link #{link_id}" }
        head :ok
        return
      end

      unless valid_razorpay_signature?(link_id, reference_id, link_status, payment_id, signature)
        Rails.logger.warn { "Razorpay shipping_callback signature invalid for link #{link_id}" }
        head :bad_request
        return
      end

      if link_status == "paid"
        amount_rupees = fetch_payment_amount_rupees(payment_id)
        if amount_rupees.nil?
          Rails.logger.error { "Razorpay shipping_callback: could not fetch payment #{payment_id}" }
          return respond_shipping_callback(order: order, notice: nil, alert: "Payment received but amount verification failed. Please contact support.")
        end

        result = Orders::ProcessShippingPayment.execute(
          order_id: order.id,
          razorpay_payment_id: payment_id,
          amount_paid: amount_rupees
        )
        unless result.success?
          Rails.logger.error { "ProcessShippingPayment failed: #{result.errors}" }
          return respond_shipping_callback(order: order, notice: nil, alert: result.errors.to_s)
        end
        return respond_shipping_callback(order: order, notice: "Shipping payment confirmed. Shipment is being processed.", alert: nil)
      else
        Rails.logger.info { "Razorpay shipping_callback status=#{link_status} for link #{link_id}" }
        return respond_shipping_callback(order: order, notice: nil, alert: "Payment status is #{link_status}.")
      end

    rescue StandardError => e
      Rails.logger.error { "Razorpay shipping_callback error: #{e.class}: #{e.message}" }
      head :ok
    end

    private

    def valid_razorpay_signature?(link_id, reference_id, link_status, payment_id, signature)
      return false if signature.blank?

      secret = Rails.application.credentials.razorpay[:key_secret].to_s
      return false if secret.blank?

      payload = "#{link_id}|#{reference_id}|#{link_status}|#{payment_id}"
      expected = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    def fetch_payment_amount_rupees(payment_id)
      return nil if payment_id.blank?

      key_id = Rails.application.credentials.razorpay[:key_id]
      key_secret = Rails.application.credentials.razorpay[:key_secret]
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

    def respond_shipping_callback(order:, notice:, alert:)
      if request.format.html?
        redirect_to("/orders/#{order.id}", notice: notice, alert: alert)
      else
        head :ok
      end
    end
  end
end
