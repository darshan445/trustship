# frozen_string_literal: true

module Orders
  class CalculateShippingCost
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
        pt = rate_payment_type_for_order
        rate = ShippingRate.find_for_order(payment_type: pt, weight_grams: order.weight_grams)
        raise_string_error("No active shipping rate for #{pt} at #{order.weight_grams}g") if rate.blank?

        rate.amount
      end
    end

    private

    attr_reader :order

    def rate_payment_type_for_order
      order.full_prepaid? ? "prepaid" : "cod"
    end
  end
end
