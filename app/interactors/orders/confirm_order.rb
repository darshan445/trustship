# frozen_string_literal: true

module Orders
  class ConfirmOrder
    include ExecuteMethodHelper
    include LogHelper

    TRIGGERED_BY = %w[buyer seller].freeze

    def self.execute(order_id:, triggered_by:)
      new(order_id: order_id, triggered_by: triggered_by).execute
    end

    def initialize(order_id:, triggered_by:)
      @order_id = order_id
      @triggered_by = triggered_by
    end

    def execute
      execute_log_and_return_open_struct do
        validate_triggered_by!
        order = find_order!
        raise_string_error("Order cannot transition to confirmed") unless order.may_confirm?

        order.pending_event_triggered_by = triggered_by
        order.confirm!
        order
      end
    end

    private

    attr_reader :order_id, :triggered_by

    def validate_triggered_by!
      return if TRIGGERED_BY.include?(triggered_by.to_s)

      raise_string_error("triggered_by must be buyer or seller")
    end

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end
  end
end
