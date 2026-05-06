# frozen_string_literal: true

module BuyerAddresses
  class ValidateWithGoogleMaps
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(buyer_address:)
      new(buyer_address: buyer_address).execute
    end

    def initialize(buyer_address:)
      @buyer_address = buyer_address
    end

    def execute
      execute_log_and_return_open_struct do
        if buyer_address.reusable?
          next { buyer_address: buyer_address, skipped: true }
        end

        geocode_result = GoogleMaps::GeocodeAddress.execute(address: buyer_address.raw_address)
        unless geocode_result.success?
          buyer_address.update!(address_confidence: "unknown", validated_at: Time.current)
          next { buyer_address: buyer_address.reload, skipped: false }
        end

        payload = geocode_result.data
        buyer_address.update!(
          address_formatted: payload[:formatted_address],
          address_confidence: payload[:confidence],
          latitude: payload[:latitude],
          longitude: payload[:longitude],
          validated_at: Time.current
        )

        { buyer_address: buyer_address.reload, skipped: false }
      end
    end

    private

    attr_reader :buyer_address
  end
end
