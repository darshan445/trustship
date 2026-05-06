# frozen_string_literal: true

module Orders
  class SendConfirmationReminder
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
        next order if confirmation.blank? || confirmation.responded_at.present? || confirmation.reminded_at.present?

        result = Whatsapp::SendTemplateMessage.execute(
          to: order.buyer.phone,
          template_name: Rails.application.credentials.dig(:meta, :reminder_template_name),
          parameters: [order.buyer.name, order.product_name]
        )
        raise_string_error(result.errors.to_s) unless result.success?

        confirmation.update!(reminded_at: Time.current)
        log_gate_event("confirmation_reminder_sent", reminded_at: Time.current)
        Orders::NotifySellerUnconfirmedJob.set(wait: 4.hours).perform_later(order.id)
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
