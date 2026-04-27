# frozen_string_literal: true

module Orders
  class MarkUndeliverable
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, reason: nil)
      new(order_id: order_id, reason: reason).execute
    end

    def initialize(order_id:, reason: nil)
      @order_id = order_id
      @reason = reason
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order!
        raise_string_error("Order cannot transition to undeliverable") unless order.may_mark_undeliverable?

        order.pending_event_triggered_by = "system"
        order.pending_event_metadata = { reason: reason.presence }.compact
        order.mark_undeliverable!
        order
      end
    end

    private

    attr_reader :order_id, :reason

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end
  end
end
