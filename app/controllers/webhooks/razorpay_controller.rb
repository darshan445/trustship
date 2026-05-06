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
      Rails.logger.info { "Razorpay payment callback ignored after orders table cleanup" }
      head :ok
    rescue StandardError => e
      Rails.logger.error { "Razorpay payment_callback error: #{e.class}: #{e.message}" }
      head :ok
    end

    def shipping_callback
      Rails.logger.info { "Razorpay shipping callback ignored after orders table cleanup" }
      head :ok

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

    def respond_shipping_callback(order:, notice:, alert:); end
  end
end
