# frozen_string_literal: true

module Orders
  class NotifySellerUnpaidAdvance
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
        advance_payment = order.order_advance_payment
        return order if advance_payment.nil? || advance_payment.paid? || advance_payment.seller_notified_at.present?

        validate_result_without_raising_error(
          Whatsapp::SendTextMessage.execute(
            to: order.seller.phone,
            text: "⚠️ Order ##{order.id.to_s.delete('-')[0, 8].upcase}\n\n" \
                  "Buyer #{order.buyer.name} has not paid ₹#{advance_payment.amount} advance for #{order.product_name} after 8 hours.\n\n" \
                  "Payment link was sent twice. No payment.\n\n" \
                  "What would you like to do?\n" \
                  "Reply KEEP to keep waiting.\n" \
                  "Reply CANCEL to cancel this order."
          )
        )

        advance_payment.update!(seller_notified_at: Time.current)
        log_gate_event("seller_notified_unpaid_advance", notified_at: advance_payment.seller_notified_at)

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
# frozen_string_literal: true

module Orders
  class NotifySellerUnpaidAdvance
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
        advance_payment = order.order_advance_payment
        return order if advance_payment.nil? || advance_payment.paid? || advance_payment.seller_notified_at.present?

        Whatsapp::SendTextMessage.execute(
          to: order.seller.phone,
          message: "Order ##{order.id.first(8).upcase}\n\n" \
            "Buyer #{order.buyer.name} has not paid ₹#{advance_payment.amount} advance for " \
            "#{order.product_name} after 8 hours.\n\n" \
            "Payment link was sent twice. No payment.\n\n" \
            "What would you like to do?\n" \
            "Reply KEEP to keep waiting.\n" \
            "Reply CANCEL to cancel this order."
        )

        advance_payment.update!(seller_notified_at: Time.current)
        log_event(order, "seller_notified_unpaid_advance", { notified_at: Time.current })
        advance_payment
      end
    end

    private

    attr_reader :order
  end
end
