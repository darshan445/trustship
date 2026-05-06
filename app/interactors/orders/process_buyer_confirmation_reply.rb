# frozen_string_literal: true

module Orders
  class ProcessBuyerConfirmationReply
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:, message:)
      new(order: order, message: message).execute
    end

    def initialize(order:, message:)
      @order = order
      @message = message.to_s
    end

    def execute
      execute_log_and_return_open_struct do
        confirmation = order.order_confirmation
        next order if confirmation.blank? || confirmation.responded_at.present?

        reply_type = OrderConfirmation.classify_reply(message)

        case reply_type
        when "confirmed"
          confirmation.update!(response: "confirmed", responded_at: Time.current)
          log_gate_event("buyer_confirmed", reply: message, responded_at: Time.current)
          Orders::RunGateFourJob.perform_later(order.id)
        when "cancelled"
          confirmation.update!(response: "cancelled", responded_at: Time.current)
          log_gate_event("buyer_cancelled", reply: message)
          order.cancel! if order.may_cancel?
          validate_result_without_raising_error(
            Whatsapp::SendTextMessage.execute(
              to: order.seller.phone,
              text: "Buyer #{order.buyer.name} cancelled order #{order.id.to_s.delete('-').first(8).upcase}."
            )
          )
        else
          confirmation.update!(
            response: "address_correction",
            corrected_address: message,
            responded_at: Time.current
          )
          log_gate_event("buyer_corrected_address", corrected_address: message)

          new_address_result = validate_result(BuyerAddresses::FindOrCreate.execute(buyer: order.buyer, raw_address: message))
          new_address = new_address_result.data[:buyer_address]
          order.update!(buyer_address_id: new_address.id)
          validate_result_without_raising_error(BuyerAddresses::ValidateWithGoogleMaps.execute(buyer_address: new_address))

          confirmation.update!(
            sent_at: Time.current,
            reminded_at: nil,
            responded_at: nil,
            response: nil,
            corrected_address: message
          )
          validate_result(Orders::SendConfirmation.execute(order: order))
        end

        order.reload
      end
    end

    private

    attr_reader :order, :message

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
