# frozen_string_literal: true

module Orders
  class ProcessSellerConfirmationDecision
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:, decision:)
      new(order: order, decision: decision).execute
    end

    def initialize(order:, decision:)
      @order = order
      @decision = decision.to_s
    end

    def execute
      execute_log_and_return_open_struct do
        confirmation = order.order_confirmation
        next order if confirmation.blank?

        case decision
        when "keep_waiting"
          confirmation.update!(seller_decision: "keep_waiting", seller_decided_at: Time.current)
          log_gate_event("seller_decided_keep_waiting", decided_at: Time.current)
          validate_result_without_raising_error(Orders::SendConfirmationReminder.execute(order: order))
        when "cancelled"
          confirmation.update!(seller_decision: "cancelled", seller_decided_at: Time.current)
          log_gate_event("seller_cancelled_order", reason: "buyer_no_response", decided_at: Time.current)
          order.cancel! if order.may_cancel?
        end

        order.reload
      end
    end

    private

    attr_reader :order, :decision

    def log_gate_event(name, metadata)
      order.order_events.create!(
        from_state: order.aasm_state,
        to_state: order.aasm_state,
        event_name: name,
        triggered_by: "seller",
        metadata: metadata
      )
    end
  end
end
