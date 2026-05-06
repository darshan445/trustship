# frozen_string_literal: true

module BuyerAddresses
  class FindOrCreate
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(buyer:, raw_address:)
      new(buyer: buyer, raw_address: raw_address).execute
    end

    def initialize(buyer:, raw_address:)
      @buyer = buyer
      @raw_address = raw_address.to_s
    end

    def execute
      execute_log_and_return_open_struct do
        normalized = raw_address.strip.downcase
        raise_string_error("Raw address is blank") if normalized.blank?

        existing = buyer.buyer_addresses
                       .reusable
                       .find_by("LOWER(TRIM(raw_address)) = ?", normalized)

        if existing.present?
          { buyer_address: existing, reused: true }
        else
          buyer_address = buyer.buyer_addresses.create!(
            raw_address: raw_address,
            address_confidence: "pending",
            is_primary: buyer.buyer_addresses.none?
          )

          { buyer_address: buyer_address, reused: false }
        end
      end
    end

    private

    attr_reader :buyer, :raw_address
  end
end
