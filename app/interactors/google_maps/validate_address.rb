# frozen_string_literal: true

module GoogleMaps
  # Thin wrapper for callers that still pass an +Order+ (same behaviour as buyer address validation).
  class ValidateAddress
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:)
      new(order: order).execute
    end

    def initialize(order:)
      @order = order
    end

    def execute
      execute_log_and_return_open_struct do
        query = build_query(@order)
        raise_string_error("Address query is empty") if query.blank?

        validate_result(GoogleMaps::AddressValidation.execute(address: query)).data
      end
    end

    private

    attr_reader :order

    def build_query(order)
      order.buyer_address&.raw_address.to_s.strip
    end
  end
end
