# frozen_string_literal: true

module Orders
  class SendConfirmation
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
        buyer = order.buyer
        seller = order.seller
        address = order.buyer_address

        full_address = address&.address_formatted.presence || address&.raw_address.presence || "Address not available"
        amount_string = "#{format_amount(order.amount)} (#{order.full_cod? ? 'Cash on Delivery' : 'Prepaid'})"

        parameters = [
          buyer.name,
          seller.business_name,
          order.product_name,
          full_address,
          amount_string
        ]

        result = Whatsapp::SendTemplateMessage.execute(
          to: buyer.phone,
          template_name: Rails.application.credentials.dig(:meta, :confirmation_template_name),
          parameters: parameters
        )

        unless result.success?
          log_gate_event("confirmation_send_failed", errors: result.errors.to_s)
          raise_string_error(result.errors.to_s)
        end

        confirmation = order.order_confirmation || order.build_order_confirmation
        confirmation.update!(
          sent_at: Time.current,
          reminded_at: nil,
          responded_at: nil,
          response: nil,
          seller_notified_at: nil,
          seller_decision: "pending",
          seller_decided_at: nil
        )

        log_gate_event("confirmation_sent", buyer_phone: buyer.phone, sent_at: Time.current)
        Orders::SendConfirmationReminderJob.set(wait: 4.hours).perform_later(order.id)
        confirmation
      end
    end

    private

    attr_reader :order

    def format_amount(amount)
      "₹#{format('%.2f', amount.to_d)}"
    end

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
