# frozen_string_literal: true

module Orders
  class CancelOrder
    include ExecuteMethodHelper
    include LogHelper

    TRIGGERED_BY = %w[seller system].freeze

    def self.execute(order_id:, reason: nil, triggered_by:)
      new(order_id: order_id, reason: reason, triggered_by: triggered_by).execute
    end

    def initialize(order_id:, reason: nil, triggered_by:)
      @order_id = order_id
      @reason = reason
      @triggered_by = triggered_by
    end

    def execute
      execute_log_and_return_open_struct do
        validate_triggered_by!
        order = find_order!
        raise_string_error("Order cannot be cancelled") unless order.may_cancel?

        order.pending_event_triggered_by = triggered_by
        order.pending_event_metadata = { reason: reason.presence }.compact
        order.cancel!
        order
      end
    end

    private

    attr_reader :order_id, :reason, :triggered_by

    def validate_triggered_by!
      return if TRIGGERED_BY.include?(triggered_by.to_s)

      raise_string_error("triggered_by must be seller or system")
    end

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end
  end
end
