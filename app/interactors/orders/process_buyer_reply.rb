# frozen_string_literal: true

module Orders
  class ProcessBuyerReply
    include ExecuteMethodHelper
    include LogHelper
    include PhoneHelper

    YES_KEYWORDS = %w[yes y haan han ha ok okay confirm confirmed].freeze
    NO_KEYWORDS = %w[no n nahi nhi nope cancel wrong galat].freeze

    def self.execute(phone:, reply:)
      new(phone: phone, reply: reply).execute
    end

    def initialize(phone:, reply:)
      @phone = phone
      @reply = reply
    end

    def execute
      execute_log_and_return_open_struct do
        normalized = reply.to_s.strip.downcase
        intent = classify_intent(normalized)

        buyer = find_buyer!
        order = find_pending_confirmation_order!(buyer)

        case intent
        when :yes
          validate_result(Orders::ConfirmOrder.execute(order_id: order.id, triggered_by: "buyer"))
          validate_result(Orders::RunGateFour.execute(order_id: order.id))
          order.reload
        when :no
          validate_result(Orders::MarkAddressMismatch.execute(order_id: order.id))
          order.reload
        when :unknown
          Rails.logger.info { "Unknown reply from #{phone}: #{reply}" }
          order
        end
      end
    end

    private

    attr_reader :phone, :reply

    def classify_intent(normalized)
      return :yes if YES_KEYWORDS.include?(normalized)
      return :no if NO_KEYWORDS.include?(normalized)

      :unknown
    end

    def find_buyer!
      p = normalize_phone(phone)
      raise_string_error("Buyer not found") if p.blank?
      raise_string_error("Buyer not found") unless p.match?(Buyer::PHONE_REGEX)

      buyer = Buyer.find_by(phone: p)
      raise_string_error("Buyer not found") if buyer.blank?

      buyer
    end

    def find_pending_confirmation_order!(buyer)
      order = buyer.orders
        .where(aasm_state: "pending_verification")
        .where.not(confirmation_sent_at: nil)
        .order(created_at: :desc)
        .first

      raise_string_error("No pending order found for this buyer") if order.blank?

      order
    end
  end
end
