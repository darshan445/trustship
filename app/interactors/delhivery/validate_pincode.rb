# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "ostruct"

module Delhivery
  class ValidatePincode
    include ExecuteMethodHelper
    include LogHelper

    PINCODE_REGEX = /\A\d{6}\z/

    def self.execute(pincode:)
      new(pincode: pincode).execute
    end

    def initialize(pincode:)
      @pincode = pincode.to_s.strip
    end

    def execute
      execute_log_and_return_open_struct do
        validate_pincode_format!
        body = call_delhivery_api(@pincode)
        Rails.logger.debug { "Delhivery pincode response: #{body.inspect}" } if Rails.env.development?
        parse_pincode_response(@pincode, body)
      end
    end

    private

    def validate_pincode_format!
      if @pincode.blank? || !@pincode.match?(PINCODE_REGEX)
        raise_string_error("Pincode must be exactly 6 digits")
      end
    end

    def call_delhivery_api(pincode)
      creds = Rails.application.credentials.delhivery
      raise_string_error("Delhivery API key not configured") if creds.blank? || creds[:api_key].blank?

      api_key = creds[:api_key].to_s.strip
      uri = URI::HTTPS.build(
        host: "track.delhivery.com",
        path: "/c/api/pin-codes/json/",
        query: URI.encode_www_form("filter_codes" => pincode)
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Token #{api_key}"
      request["Content-Type"] = "application/json"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess) && response.code == "200"
        raise_string_error("Delhivery API error: #{response.code}")
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise_string_error("Delhivery API error: invalid JSON")
    end

    def parse_pincode_response(pincode, body)
      codes = body["delivery_codes"]
      if codes.blank?
        return ::OpenStruct.new(
          pincode: pincode,
          valid: false,
          serviceable: false,
          city: nil,
          state: nil,
          is_oda: false,
          cod_supported: false,
          pickup_supported: false,
          raw_response: body
        )
      end

      postal = codes.first&.fetch("postal_code", nil)
      if postal.blank?
        return ::OpenStruct.new(
          pincode: pincode,
          valid: false,
          serviceable: false,
          city: nil,
          state: nil,
          is_oda: false,
          cod_supported: false,
          pickup_supported: false,
          raw_response: body
        )
      end

      ::OpenStruct.new(
        pincode: pincode,
        valid: true,
        serviceable: serviceable?(postal),
        city: postal["city"].presence,
        state: postal["state"].presence,
        is_oda: cast_bool(postal["is_oda"]),
        cod_supported: postal["cod"].to_s == "Y",
        pickup_supported: postal["pickup"].to_s == "Y",
        raw_response: body
      )
    end

    def serviceable?(postal_code)
      postal_code["cod"].to_s == "Y" && postal_code["pickup"].to_s == "Y"
    end

    def cast_bool(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
