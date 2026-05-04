# frozen_string_literal: true

require "json"
require "net/http"
require "ostruct"
require "uri"

module Delhivery
  class CreateShipment
    include ExecuteMethodHelper
    include LogHelper

    API_PATH = "/api/cmu/create.json"
    READ_TIMEOUT = 15
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
        seller = order.seller
        buyer = order.buyer

        raise_string_error("Order must be in green zone to create shipment") unless order.green_zone?
        unless seller.pickup_address_complete?
          raise_string_error("Pickup address not set. Please complete your profile first.")
        end

        payload = build_shipment_payload(order, buyer, seller)
        parsed = call_delhivery_api(payload)

        pkg = first_package(parsed)
        raise_string_error("Delhivery rejected shipment: empty packages response") if pkg.blank?

        status = pkg["status"].to_s
        remarks = pkg["remarks"].to_s
        unless status.casecmp("success").zero?
          raise_string_error("Delhivery rejected shipment: #{remarks.presence || status}")
        end

        awb = pkg["waybill"].to_s.presence || pkg["AWB"].to_s.presence
        raise_string_error("Delhivery rejected shipment: missing waybill") if awb.blank?

        Rails.logger.info { "Delhivery shipment created for order #{order.id} — AWB: #{awb}" }

        OpenStruct.new(
          awb_number: awb,
          delhivery_shipment_id: awb,
          status: "Success"
        )
      end
    end

    private

    attr_reader :order_id

    def find_order!
      order = Order.includes(:seller, :buyer).find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end

    def build_shipment_payload(order, buyer, seller)
      payment = determine_payment_string(order)
      cod_amt = determine_cod_amount(order).to_f
      pickup_name = seller.delhivery_pickup_location_name.to_s
      raise_string_error("Delhivery pickup location name missing for seller") if pickup_name.blank?

      {
        shipments: [
          {
            name: buyer.name.to_s,
            add: "#{order.address_line}, #{order.city}, #{order.state} #{order.pincode}",
            city: order.city.to_s,
            state: order.state.to_s,
            country: "India",
            pin: order.pincode.to_s,
            phone: buyer.phone.to_s,
            order: order.id.to_s,
            payment_mode: payment,
            cod_amount: cod_amt,
            products_desc: order.product_name.to_s,
            hsn_code: "",
            cod_info: "",
            weight: (order.weight_grams.to_f / 1000).round(2),
            seller_name: seller.business_name.to_s,
            seller_add: seller.pickup_address_line.to_s,
            seller_city: seller.pickup_city.to_s,
            seller_state: seller.pickup_state.to_s,
            seller_pin: seller.pickup_pincode.to_s,
            seller_cust_id: seller.id.to_s,
            seller_gst_tin: "",
            shipping_mode: "Surface",
            address_type: "home"
          }
        ],
        pickup_location: {
          name: pickup_name
        }
      }
    end

    def determine_payment_string(order)
      order.full_prepaid? ? "Prepaid" : "COD"
    end

    def determine_cod_amount(order)
      if order.full_prepaid?
        0
      elsif order.partial_cod?
        (order.amount - order.advance_amount).round(2)
      else
        order.amount
      end
    end

    def call_delhivery_api(payload_hash)
      delhivery_config = Rails.application.credentials.delhivery
      api_key = delhivery_config[:api_key].to_s
      base_url = delhivery_config[:base_url].to_s
      raise_string_error("Delhivery API key not configured") if api_key.blank?
      raise_string_error("Delhivery base_url not configured") if base_url.blank?

      uri = URI.join(base_url.end_with?("/") ? base_url : "#{base_url}/", API_PATH.delete_prefix("/"))

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = READ_TIMEOUT
      http.open_timeout = OPEN_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Token #{api_key}"
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = URI.encode_www_form(
        format: "json",
        data: JSON.generate(payload_hash)
      )

      response = http.request(request)
      code = response.code.to_i
      raise_string_error("Delhivery API error: [#{code}]") unless code == 200

      body = response.body.to_s
      JSON.parse(body)
    rescue JSON::ParserError
      raise_string_error("Delhivery API error: invalid JSON response")
    end

    def first_package(parsed)
      return nil unless parsed.is_a?(Hash)

      pkgs = parsed["packages"] || parsed.dig("data", "packages")
      Array(pkgs).first
    end
  end
end
