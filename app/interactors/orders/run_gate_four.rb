# frozen_string_literal: true

module Orders
  class RunGateFour
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
        raise_string_error("Order must be confirmed for Gate 4") unless order.confirmed?

        advance_amount = order.product&.cod_minimum_advance.to_d
        unless order.payment_type == "full_cod" && advance_amount.positive?
          log_gate_event(
            order,
            "gate_4_skipped",
            reason: order.payment_type != "full_cod" ? "prepaid_order" : "no_advance_configured_for_product"
          )
          return order
        end

        result = Orders::SendAdvancePaymentRequest.execute(order: order)
        if result.failure?
          log_gate_event(order, "gate_4_failed", errors: result.errors)
          Orders::RunGateFourJob.set(wait: 5.minutes).perform_later(order.id)
          return order
        end

        log_gate_event(order, "gate_4_started", advance_amount: advance_amount, sent_at: Time.current)
        Rails.logger.info { "Gate 4 started for order #{order.id} — COD advance requested" }

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
