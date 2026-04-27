# frozen_string_literal: true

require "ostruct"

module Buyers
  class CalculateRiskScore
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(buyer_id:)
      new(buyer_id: buyer_id).execute
    end

    def initialize(buyer_id:)
      @buyer_id = buyer_id
    end

    def execute
      execute_log_and_return_open_struct do
        buyer = find_buyer!
        risk_level = calculate_risk_level(buyer)
        buyer.update!(risk_level: risk_level)
        Rails.logger.info { "Buyer #{buyer.phone} risk score: #{risk_level}" }

        buyer.reload

        ::OpenStruct.new(
          buyer: buyer,
          risk_level: risk_level,
          rto_count: buyer.rto_count,
          successful_delivery_count: buyer.successful_delivery_count,
          is_high_risk: risk_level == "high",
          is_first_time_buyer: first_time_buyer?(buyer)
        )
      end
    end

    private

    attr_reader :buyer_id

    def find_buyer!
      buyer = Buyer.find_by(id: buyer_id)
      raise_string_error("Buyer not found") if buyer.blank?

      buyer
    end

    def calculate_risk_level(buyer)
      rto = buyer.rto_count
      succ = buyer.successful_delivery_count

      return "high" if rto >= 3
      return "high" if rto >= 2 && succ < rto
      return "medium" if rto == 1
      return "medium" if rto.positive? && succ >= rto

      "low"
    end

    def first_time_buyer?(buyer)
      buyer.rto_count.zero? && buyer.successful_delivery_count.zero?
    end
  end
end
