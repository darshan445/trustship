# frozen_string_literal: true

require "json"
require "net/http"
require "ostruct"
require "rexml/document"
require "uri"

module Delhivery
  class RegisterPickupLocation
    include ExecuteMethodHelper
    include LogHelper

    CREATE_PATH = "/api/backend/clientwarehouse/create/"
    UPDATE_PATH = "/api/backend/clientwarehouse/update/"
    READ_TIMEOUT = 15
    OPEN_TIMEOUT = 5

    def self.execute(seller_id:)
      new(seller_id: seller_id).execute
    end

    def initialize(seller_id:)
      @seller_id = seller_id
    end

    def execute
      execute_log_and_return_open_struct do
        seller = Seller.find_by(id: seller_id)
        raise_string_error("Seller not found") if seller.blank?
        raise_string_error("Pickup address incomplete") unless seller.pickup_address_saved?

        location_name = "TS_#{seller.id.to_s.first(8).upcase}"
        body = build_request_body(seller, location_name)

        register_or_update(body, location_name)
        seller.update!(delhivery_pickup_location_name: location_name)

        Rails.logger.info { "Pickup location registered for seller #{seller.id}: #{location_name}" }

        OpenStruct.new(
          location_name: location_name,
          registered: true,
          seller: seller
        )
      end
    end

    private

    attr_reader :seller_id

    def register_or_update(body, location_name)
      create_response = call_delhivery_api(:post, CREATE_PATH, body)
      return create_response if create_response.success

      if duplicate_error?(create_response)
        update_response = call_delhivery_api(:put, UPDATE_PATH, body)
        return update_response if update_response.success

        update_error = update_response.errors.to_a.join(", ").presence || update_response.message.presence
        raise_string_error("Delhivery location update failed: #{update_error || update_response.code}")
      end

      create_error = create_response.errors.to_a.join(", ").presence || create_response.message.presence
      raise_string_error("Delhivery registration failed: #{create_error || create_response.code}")
    end

    def duplicate_error?(response)
      response.errors.to_a.any? do |error_text|
        text = error_text.to_s.downcase
        text.include?("already exists") || text.include?("duplicate")
      end
    end

    def build_request_body(seller, location_name)
      {
        name: location_name,
        email: "#{seller.phone}@trustship.site",
        phone: seller.phone.to_s,
        address: seller.pickup_address_line.to_s,
        city: seller.pickup_city.to_s,
        country: "India",
        pin: seller.pickup_pincode.to_s,
        state: seller.pickup_state.to_s,
        return_address: seller.pickup_address_line.to_s,
        return_pin: seller.pickup_pincode.to_s
      }
    end

    def call_delhivery_api(method, path, body)
      delhivery_config = Rails.application.credentials.delhivery
      api_key = delhivery_config[:api_key].to_s
      base_url = delhivery_config[:base_url].to_s
      raise_string_error("Delhivery API key not configured") if api_key.blank?
      raise_string_error("Delhivery base_url not configured") if base_url.blank?

      uri = URI.join(base_url.end_with?("/") ? base_url : "#{base_url}/", path.delete_prefix("/"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = READ_TIMEOUT
      http.open_timeout = OPEN_TIMEOUT

      request = if method == :put
        Net::HTTP::Put.new(uri.request_uri)
      else
        Net::HTTP::Post.new(uri.request_uri)
      end

      request["Authorization"] = "Token #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)

      response = http.request(request)
      doc = REXML::Document.new(response.body.to_s)
      success = doc.elements["root/success"]&.text&.downcase == "true"
      message = doc.elements["root/data/message"]&.text
      errors = doc.elements.collect("root/error/list-item") { |element| element.text }

      OpenStruct.new(
        code: response.code.to_i,
        success: success,
        message: message,
        errors: errors,
        raw: response.body.to_s
      )
    rescue REXML::ParseException
      OpenStruct.new(
        code: response&.code.to_i || 500,
        success: false,
        message: nil,
        errors: [],
        raw: response&.body.to_s
      )
    end
  end
end
