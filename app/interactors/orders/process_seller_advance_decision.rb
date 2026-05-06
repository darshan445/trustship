# frozen_string_literal: true

module Orders
  class ProcessSellerAdvanceDecision
    include ExecuteMethodHelper
    include LogHelper

    VALID_DECISIONS = %w[keep_waiting cancelled].freeze

    def self.execute(order:, decision:)
      new(order: order, decision: decision).execute
    end

    def initialize(order:, decision:)
      @order = order
      @decision = decision.to_s
    end

    def execute
      execute_log_and_return_open_struct do
        raise_string_error("Invalid decision") unless VALID_DECISIONS.include?(decision)

        advance_payment = order.order_advance_payment
        return order if advance_payment.nil? || advance_payment.paid?

        case decision
        when "keep_waiting"
          advance_payment.update!(seller_decision: "keep_waiting", seller_decided_at: Time.current)
          log_gate_event("seller_decided_keep_waiting_advance", decided_at: advance_payment.seller_decided_at)
          validate_result_without_raising_error(Orders::SendAdvanceReminder.execute(order: order, force: true))
        when "cancelled"
          advance_payment.update!(seller_decision: "cancelled", seller_decided_at: Time.current)
          log_gate_event("seller_cancelled_advance_unpaid", decided_at: advance_payment.seller_decided_at)
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
        triggered_by: "system",
        metadata: metadata
      )
    end
  end
end
# frozen_string_literal: true

module Orders
  class ProcessSellerAdvanceDecision
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
        advance_payment = order.order_advance_payment
        return order if advance_payment.nil?

        case decision
        when "keep_waiting"
          advance_payment.update!(seller_decision: "keep_waiting", seller_decided_at: Time.current)
          log_event(order, "seller_decided_keep_waiting_advance", { decided_at: Time.current })
          Orders::SendAdvanceReminder.execute(order: order)
        when "cancelled"
          advance_payment.update!(seller_decision: "cancelled", seller_decided_at: Time.current)
          log_event(order, "seller_cancelled_advance_unpaid", { decided_at: Time.current })
          order.cancel! if order.may_cancel?
        else
          raise_string_error("Invalid seller decision")
        end

        advance_payment
      end
    end

    private

    attr_reader :order, :decision
  end
end
