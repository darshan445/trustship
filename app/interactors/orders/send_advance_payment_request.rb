# frozen_string_literal: true

module Orders
  class SendAdvancePaymentRequest
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:)
      new(order: order).execute
    end

    def initialize(order:)
      @order = order
    end

    def execute
      execute_log_and_return_open_struct do
        existing = order.order_advance_payment
        return order if existing&.paid?
        return order if existing&.awaiting_payment?

        link_result = validate_result(Orders::CreateAdvancePaymentLink.execute(order: order))
        advance_amount = link_result.data[:amount]
        params = [
          order.buyer.name,
          order.product_name,
          "₹#{order.amount}",
          "₹#{advance_amount}",
          link_result.data[:payment_link_url],
          order.seller.business_name
        ]

        whatsapp_result = Whatsapp::SendTemplateMessage.execute(
          to: order.buyer.phone,
          template_name: Rails.application.credentials.dig(:meta, :prepaid_incentive_template_name),
          parameters: params
        )
        unless whatsapp_result.success?
          log_gate_event("advance_payment_send_failed", errors: whatsapp_result.errors)
          raise_string_error(whatsapp_result.errors)
        end

        advance = existing || OrderAdvancePayment.new(order: order)
        advance.update!(
          amount: advance_amount,
          razorpay_payment_link_id: link_result.data[:payment_link_id],
          razorpay_payment_link_url: link_result.data[:payment_link_url],
          sent_at: Time.current,
          seller_decision: "pending",
          seller_decided_at: nil
        )

        log_gate_event("advance_payment_sent", amount: advance_amount, sent_at: advance.sent_at)
        Orders::SendAdvanceReminderJob.set(wait: 4.hours).perform_later(order.id)

        order
      end
    end

    private

    attr_reader :order

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
