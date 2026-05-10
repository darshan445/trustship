# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module GoogleMaps
  # Calls Google Address Validation API (REST v1:validateAddress).
  # Enable "Address Validation API" on the same Google Cloud project as your API key.
  # Note: Google often returns HTTP 400 (not 403) with a JSON body for invalid keys — see +api_error_message+.
  #
  # https://developers.google.com/maps/documentation/address-validation/requests-validate
  class AddressValidation
    include ExecuteMethodHelper
    include LogHelper

    VALIDATE_URL = "https://addressvalidation.googleapis.com/v1:validateAddress"

    def self.execute(address:, region_code: nil)
      new(address: address, region_code: region_code).execute
    end

    def initialize(address:, region_code: nil)
      @address = address.to_s.strip
      @region_code = region_code.presence ||
        Rails.application.credentials.dig(:google, :address_validation_region_code).to_s.presence ||
        "IN"
    end

    def execute
      execute_log_and_return_open_struct do
        raise_string_error("Address cannot be blank") if address.blank?

        body = build_request_body
        payload = post_api(body)
        parse_success_payload(payload)
      end
    end

    private

    attr_reader :address, :region_code

    def build_request_body
      line = address.truncate(280, omission: "")
      {
        "address" => {
          "revision" => 0,
          "regionCode" => region_code,
          "addressLines" => [ line ]
        }
      }
    end

    def post_api(body_hash)
      api_key = Rails.application.credentials.dig(:google, :maps_api_key).to_s
      raise_string_error("Address Validation API error: missing API key") if api_key.blank?

      uri = URI.parse("#{VALIDATE_URL}?#{URI.encode_www_form(key: api_key)}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 20

      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"] = "application/json; charset=utf-8"
      req.body = JSON.generate(body_hash)

      response = http.request(req)

      unless response.is_a?(Net::HTTPSuccess)
        raise_string_error(api_error_message(response))
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise_string_error("Address Validation API error: invalid JSON response")
    rescue StandardError => e
      raise_string_error("Address Validation API error: #{e.message}")
    end

    def api_error_message(response)
      body = response.body.to_s
      parsed = JSON.parse(body)
      if parsed.is_a?(Hash) && parsed["error"].is_a?(Hash)
        msg = parsed.dig("error", "message").presence
        status = parsed.dig("error", "status").presence
        return "#{msg} (#{status}, HTTP #{response.code})" if msg.present?

        return "HTTP #{response.code}: #{parsed['error'].to_json.truncate(500)}"
      end
      "HTTP #{response.code}: #{body.truncate(500)}"
    rescue JSON::ParserError
      "HTTP #{response.code}: #{body.truncate(500)}"
    end

    def parse_success_payload(payload)
      if payload["error"].present?
        msg = payload.dig("error", "message").presence || payload["error"].to_json
        raise_string_error("Address Validation API error: #{msg}")
      end

      result = payload["result"]
      if result.blank?
        return {
          formatted_address: nil,
          latitude: nil,
          longitude: nil,
          confidence: "failed"
        }
      end

      verdict = result["verdict"] || {}
      addr = result["address"] || {}
      geo = result["geocode"] || {}

      formatted = addr["formattedAddress"].presence
      loc = geo["location"] || {}
      lat = loc["latitude"]
      lng = loc["longitude"]

      {
        formatted_address: formatted,
        latitude: lat,
        longitude: lng,
        confidence: map_confidence(verdict, addr, geo, formatted, lat, lng)
      }
    end

    # Geocode must include at least one street-level type, unless validation already reached a building.
    DELIVERABLE_PLACE_TYPES = %w[street_address premise subpremise route].freeze

    def map_confidence(verdict, address, geo, formatted, lat, lng)
      val = verdict["validationGranularity"].to_s
      next_act = verdict["possibleNextAction"].to_s
      complete = verdict.key?("addressComplete") ? verdict["addressComplete"] : nil

      missing = Array(address["missingComponentTypes"])
      unresolved = Array(address["unresolvedTokens"])

      if formatted.blank? && lat.nil? && lng.nil? && (val.blank? || val == "GRANULARITY_UNSPECIFIED")
        return "failed"
      end

      return "failed" if undeliverable_geocode?(geo, val)

      if val == "OTHER" || val == "GRANULARITY_UNSPECIFIED"
        return "failed"
      end

      if next_act == "FIX"
        return formatted.present? ? "low" : "failed"
      end

      if missing.any? || unresolved.any?
        return "low" unless %w[PREMISE SUB_PREMISE PREMISE_PROXIMITY].include?(val)
      end

      case next_act
      when "ACCEPT"
        if complete == true && %w[PREMISE SUB_PREMISE].include?(val)
          "high"
        elsif %w[PREMISE SUB_PREMISE PREMISE_PROXIMITY].include?(val)
          (verdict["hasUnconfirmedComponents"] == true) ? "medium" : "high"
        else
          "medium"
        end
      when "CONFIRM", "CONFIRM_ADD_SUBPREMISES"
        %w[PREMISE SUB_PREMISE PREMISE_PROXIMITY].include?(val) ? "medium" : "low"
      else
        case val
        when "SUB_PREMISE", "PREMISE"
          if complete == true && missing.empty? && unresolved.empty?
            "high"
          else
            "medium"
          end
        when "PREMISE_PROXIMITY"
          "medium"
        when "BLOCK", "ROUTE"
          "low"
        else
          formatted.present? ? "medium" : "failed"
        end
      end
    end

    def undeliverable_geocode?(geo, val)
      return false if %w[PREMISE SUB_PREMISE PREMISE_PROXIMITY].include?(val.to_s)

      types = Array(geo["placeTypes"]).map(&:to_s)
      return true if types.empty?

      (types & DELIVERABLE_PLACE_TYPES).empty?
    end
  end
end
