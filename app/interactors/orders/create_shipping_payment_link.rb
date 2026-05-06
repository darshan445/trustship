# frozen_string_literal: true

module Orders
  class CreateShippingPaymentLink
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
        raise_string_error("Shipping payment link flow is disabled after orders table cleanup")
      end
    end

    private

    attr_reader :order
  end
end
