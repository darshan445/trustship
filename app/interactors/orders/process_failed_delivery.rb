# frozen_string_literal: true

module Orders
  class ProcessFailedDelivery
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, remarks:)
      new(order_id: order_id, remarks: remarks).execute
    end

    def initialize(order_id:, remarks:)
      @order_id = order_id
      @remarks = remarks
    end

    def execute
      execute_log_and_return_open_struct do
        order = Order.find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        return order unless order.shipped?

        state = order.aasm_state.to_s
        order.order_events.create!(
          from_state: state,
          to_state: state,
          event_name: "delivery_failed",
          triggered_by: "system",
          metadata: { remarks: remarks.to_s }.stringify_keys
        )

        Rails.logger.info { "Failed delivery attempt for order #{order.id}: #{remarks}" }

        order.reload
      end
    end

    private

    attr_reader :order_id, :remarks
  end
end
