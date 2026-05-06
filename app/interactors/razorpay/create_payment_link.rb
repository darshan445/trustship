# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "ostruct"
require "uri"

module Razorpay
  class CreatePaymentLink
    include ExecuteMethodHelper
    include LogHelper

    RAZORPAY_HOST = "api.razorpay.com"
    RAZORPAY_PATH = "/v1/payment_links"
    READ_TIMEOUT = 15
    OPEN_TIMEOUT = 5

    # +link_purpose+ :buyer_advance — buyer order payment (default). :seller_shipping — seller pays Delhivery pass-through shipping.
    def self.execute(order_id:, amount:, payment_type:, link_purpose: :buyer_advance, description: nil, callback_url: nil)
      new(
        order_id: order_id,
        amount: amount,
        payment_type: payment_type,
        link_purpose: link_purpose,
        description: description,
        callback_url: callback_url
      ).execute
    end

    def initialize(order_id:, amount:, payment_type:, link_purpose:, description:, callback_url:)
      @order_id = order_id
      @amount = amount
      @payment_type = payment_type
      @link_purpose = link_purpose
      @description = description
      @callback_url = callback_url
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order!
        validate_amount!
        validate_buyer_payment_type! if buyer_advance?

        amount_paise = (BigDecimal(amount.to_s) * 100).to_i
        expire_by = 30.minutes.from_now.to_i
        expires_at = Time.zone.at(expire_by)

        customer_name, customer_phone = payer_contact(order)

        body_hash = build_request_body(
          order,
          customer_name,
          customer_phone,
          amount_paise,
          payment_type.to_s,
          expire_by
        )

        parsed = call_razorpay_api(body_hash)

        link_id = parsed["id"]
        short_url = parsed["short_url"]
        raise_string_error("Razorpay API error: missing link id or url") if link_id.blank? || short_url.blank?

        if buyer_advance?
          order.update!(
            razorpay_payment_link_id: link_id,
            razorpay_payment_link_url: short_url,
            payment_link_expires_at: expires_at
          )
        else
          order.update!(
            shipping_amount: BigDecimal(amount.to_s),
            shipping_payment_link_id: link_id,
            shipping_payment_link_url: short_url,
            shipping_payment_status: "pending"
          )
        end

        Rails.logger.info { "Razorpay payment link (#{link_purpose}) for order #{order.id}: #{short_url}" }

        OpenStruct.new(
          payment_link_id: link_id,
          payment_link_url: short_url,
          amount: BigDecimal(amount.to_s),
          expires_at: expires_at
        )
      end
    end

    private

    attr_reader :order_id, :amount, :payment_type, :link_purpose, :description, :callback_url

    def buyer_advance?
      link_purpose.to_sym == :buyer_advance
    end

    def validate_amount!
      raise_string_error("Amount is required") if amount.blank?
      raise_string_error("Amount must be greater than 0") unless BigDecimal(amount.to_s) > 0
    end

    def validate_buyer_payment_type!
      pt = payment_type.to_s
      unless %w[full_prepaid partial_cod].include?(pt)
        raise_string_error("payment_type must be full_prepaid or partial_cod")
      end
    end

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end

    def payer_contact(order)
      if buyer_advance?
        [ order.buyer.name.to_s, order.buyer.phone.to_s ]
      else
        [ order.seller.name.to_s, order.seller.phone.to_s ]
      end
    end

    def build_request_body(order, customer_name, customer_phone, amount_paise, pt, expire_by)
      desc = description.presence ||
        (buyer_advance? ? "Advance payment for #{order.product_name}" : "Shipping for Order ##{order.id.to_s.delete('-')[0, 8].upcase}")

      cb_url = effective_callback_url

      {
        amount: amount_paise,
        currency: "INR",
        description: desc.to_s.truncate(250),
        customer: {
          name: customer_name,
          contact: "+91#{customer_phone.to_s.gsub(/\D/, '').last(10)}"
        },
        notify: {
          sms: false,
          email: false
        },
        reminder_enable: false,
        callback_url: cb_url,
        callback_method: "get",
        expire_by: expire_by,
        notes: {
          order_id: order.id.to_s,
          payment_type: pt,
          link_purpose: buyer_advance? ? "buyer_advance" : "seller_shipping"
        }
      }
    end

    def effective_callback_url
      url = callback_url.to_s.strip
      return url if url.present?

      domain = Rails.application.credentials.app[:domain].to_s.sub(%r{\Ahttps?://}i, "").split("/").first.to_s
      raise_string_error("app domain missing in credentials") if domain.blank?

      path = buyer_advance? ? "/webhooks/razorpay" : "/webhooks/razorpay/shipping_callback"
      "https://#{domain}#{path}"
    end

    def call_razorpay_api(body_hash)
      key_id = Rails.application.credentials.razorpay[:key_id]
      key_secret = Rails.application.credentials.razorpay[:key_secret]
      raise_string_error("Razorpay credentials missing") if key_id.blank? || key_secret.blank?

      uri = URI::HTTPS.build(host: RAZORPAY_HOST, path: RAZORPAY_PATH)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = READ_TIMEOUT
      http.open_timeout = OPEN_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Basic #{basic_auth_header(key_id, key_secret)}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body_hash)

      response = http.request(request)
      code = response.code.to_i
      unless [ 200, 201 ].include?(code)
        raise_string_error("Razorpay API error: [#{code}]")
      end

      JSON.parse(response.body)
    end

    def basic_auth_header(key_id, key_secret)
      Base64.strict_encode64("#{key_id}:#{key_secret}")
    end
  end
end
