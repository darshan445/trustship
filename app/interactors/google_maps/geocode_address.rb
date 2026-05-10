# frozen_string_literal: true

# Legacy Geocoding API client. Buyer address verification uses
# +GoogleMaps::AddressValidation+ (Address Validation API) instead.

require "json"
require "net/http"
require "uri"

module GoogleMaps
  class GeocodeAddress
    include ExecuteMethodHelper
    include LogHelper

    GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"

    def self.execute(address:)
      new(address: address).execute
    end

    def initialize(address:)
      @address = address.to_s.strip
    end

    def execute
      execute_log_and_return_open_struct do
        raise_string_error("Address cannot be blank") if address.blank?

        payload = call_api
        status = payload["status"].to_s

        if status == "OK" && payload["results"].present?
          result = payload["results"].first
          location_type = result.dig("geometry", "location_type").to_s
          location = result.dig("geometry", "location") || {}

          {
            formatted_address: result["formatted_address"],
            latitude: location["lat"],
            longitude: location["lng"],
            location_type: location_type,
            confidence: confidence_for(location_type)
          }
        elsif status == "ZERO_RESULTS"
          {
            formatted_address: nil,
            latitude: nil,
            longitude: nil,
            location_type: nil,
            confidence: "failed"
          }
        else
          raise_string_error("Geocoding API error: #{status.presence || 'unknown'}")
        end
      end
    end

    private

    attr_reader :address

    def call_api
      api_key = Rails.application.credentials.dig(:google, :maps_api_key).to_s
      raise_string_error("Geocoding API error: missing API key") if api_key.blank?

      uri = URI.parse(GEOCODE_URL)
      uri.query = URI.encode_www_form(address: address, key: api_key)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15

      response = http.request(Net::HTTP::Get.new(uri.request_uri))
      raise_string_error("Geocoding API error: HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise_string_error("Geocoding API error: invalid response")
    rescue StandardError => e
      raise_string_error("Geocoding API error: #{e.message}")
    end

    def confidence_for(location_type)
      case location_type
      when "ROOFTOP"
        "high"
      when "RANGE_INTERPOLATED", "GEOMETRIC_CENTER"
        "medium"
      when "APPROXIMATE"
        "low"
      else
        "low"
      end
    end
  end
end
