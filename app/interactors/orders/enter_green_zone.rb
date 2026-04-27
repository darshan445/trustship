# frozen_string_literal: true

module Orders
  class EnterGreenZone
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, is_prepaid:, payment_reference: nil)
      new(order_id: order_id, is_prepaid: is_prepaid, payment_reference: payment_reference).execute
    end

    def initialize(order_id:, is_prepaid:, payment_reference: nil)
      @order_id = order_id
      @is_prepaid = is_prepaid
      @payment_reference = payment_reference
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order!
        raise_string_error("Order cannot transition to green_zone") unless order.may_enter_green_zone?

        order.pending_event_triggered_by = "system"
        order.pending_event_metadata = {
          is_prepaid: is_prepaid,
          payment_reference: payment_reference.presence
        }.compact
        order.enter_green_zone!
        order
      end
    end

    private

    attr_reader :order_id, :is_prepaid, :payment_reference

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end
  end
end
