# frozen_string_literal: true

module Orders
  class NotifySellerUnconfirmed
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
        confirmation = order.order_confirmation
        next order if confirmation.blank? || confirmation.responded_at.present? || confirmation.seller_notified_at.present?

        message = <<~TEXT.strip
          ⚠️ Order Update — ##{order.id.to_s.delete("-").first(8).upcase}

          Buyer #{order.buyer.name} has not confirmed their order for #{order.product_name} (₹#{format('%.2f', order.amount.to_d)}) after 8 hours.

          Two reminders have been sent. No response.

          What would you like to do?
          Reply KEEP to keep waiting.
          Reply CANCEL to cancel this order.
        TEXT

        result = Whatsapp::SendTextMessage.execute(to: order.seller.phone, text: message)
        raise_string_error(result.errors.to_s) unless result.success?

        confirmation.update!(seller_notified_at: Time.current)
        log_gate_event("seller_notified_unconfirmed", notified_at: Time.current)
        confirmation
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
