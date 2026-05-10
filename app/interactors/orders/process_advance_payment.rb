# frozen_string_literal: true

module Orders
  class ProcessAdvancePayment
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:, razorpay_payment_id:)
      new(order: order, razorpay_payment_id: razorpay_payment_id).execute
    end

    def initialize(order:, razorpay_payment_id:)
      @order = order
      @razorpay_payment_id = razorpay_payment_id
    end

    def execute
      execute_log_and_return_open_struct do
        advance_payment = order.order_advance_payment
        raise_string_error("No advance payment record found") if advance_payment.nil?
        next order if advance_payment.paid?

        advance_payment.update!(razorpay_payment_id: razorpay_payment_id, paid_at: Time.current)
        order.update!(advance_amount: advance_payment.amount)
        log_gate_event(
          "advance_payment_received",
          amount: advance_payment.amount,
          razorpay_payment_id: razorpay_payment_id,
          paid_at: advance_payment.paid_at
        )

        order.confirm! if order.may_confirm?

        validate_result_without_raising_error(
          Whatsapp::SendTextMessage.execute(
            to: order.seller.phone,
            text: "✅ Advance Received!\n\n" \
                  "Order ##{order.id.to_s.delete('-')[0, 8].upcase}\n" \
                  "Buyer #{order.buyer.name} paid ₹#{advance_payment.amount} advance for #{order.product_name}.\n\n" \
                  "Order is now confirmed. ✅"
          )
        )

        order.reload
      end
    end

    private

    attr_reader :order, :razorpay_payment_id

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
