# frozen_string_literal: true

module Orders
  class RunGateThree
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:)
      new(order_id: order_id).execute
    end

    def initialize(order_id:)
      @order_id = order_id
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order!
        raise_string_error("Order must be pending verification for Gate 3") unless order.pending_verification?

        result = Orders::SendConfirmation.execute(order: order)
        unless result.success?
          log_gate_event(order, "gate_3_failed", errors: result.errors.to_s)
          Orders::RunGateThreeJob.set(wait: 5.minutes).perform_later(order.id)
          next order.reload
        end

        log_gate_event(order, "gate_3_started", sent_at: Time.current)

        order.reload
      end
    end

    private

    attr_reader :order_id

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end

    def log_gate_event(order, event_name, metadata)
      order.order_events.create!(
        from_state: order.aasm_state,
        to_state: order.aasm_state,
        event_name: event_name,
        triggered_by: "system",
        metadata: metadata
      )
    end
  end
end
