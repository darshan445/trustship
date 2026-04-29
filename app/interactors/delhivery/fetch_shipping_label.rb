# frozen_string_literal: true

require "net/http"
require "stringio"
require "uri"

module Delhivery
  class FetchShippingLabel
    include ExecuteMethodHelper
    include LogHelper

    READ_TIMEOUT = 20
    OPEN_TIMEOUT = 5

    def self.execute(order_id:)
      new(order_id: order_id).execute
    end

    def initialize(order_id:)
      @order_id = order_id
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order!
        raise_string_error("AWB number not set on order") if order.awb_number.blank?

        body = fetch_label_pdf(order.awb_number)

        order.shipping_label.attach(
          io: StringIO.new(body),
          filename: "label_#{order.awb_number}.pdf",
          content_type: "application/pdf"
        )

        Rails.logger.info { "Shipping label attached for order #{order.id} AWB: #{order.awb_number}" }

        order.reload
      end
    end

    private

    attr_reader :order_id

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end

    def fetch_label_pdf(awb)
      delhivery_config = Rails.application.credentials.delhivery
      api_key = delhivery_config[:api_key].to_s
      base_url = delhivery_config[:base_url].to_s
      raise_string_error("Delhivery API key not configured") if api_key.blank?
      raise_string_error("Delhivery base_url not configured") if base_url.blank?

      uri = URI.join(base_url.end_with?("/") ? base_url : "#{base_url}/", "api/p/packing_slip")
      uri.query = URI.encode_www_form(wbns: awb, pdf: "true")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = READ_TIMEOUT
      http.open_timeout = OPEN_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Token #{api_key}"

      response = http.request(request)
      code = response.code.to_i
      raise_string_error("Label fetch failed: [#{code}]") unless code == 200

      response.body.to_s
    end
  end
end
