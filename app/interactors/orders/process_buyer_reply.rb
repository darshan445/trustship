# frozen_string_literal: true

module Orders
  class ProcessBuyerReply
    include ExecuteMethodHelper
    include LogHelper

    YES_KEYWORDS = %w[yes y haan han ha ok okay confirm confirmed].freeze
    NO_KEYWORDS = %w[no n nahi nhi nope cancel wrong galat].freeze

    def self.execute(order:, message:)
      new(order: order, message: message).execute
    end

    def initialize(order:, message:)
      @order = order
      @message = message
    end

    def execute
      execute_log_and_return_open_struct do
        unless order.pending_verification? && order.order_events.where(event_name: "confirmation_sent").exists?
          raise_string_error("Order is not awaiting buyer confirmation")
        end

        normalized = message.to_s.strip.downcase
        intent = classify_intent(normalized)

        case intent
        when :yes
          validate_result(Orders::ConfirmOrder.execute(order_id: order.id, triggered_by: "buyer"))
          validate_result(Orders::RunGateFour.execute(order_id: order.id))
          order.reload
        when :no
          validate_result(Orders::MarkAddressMismatch.execute(order_id: order.id))
          order.reload
        when :unknown
          Rails.logger.info { "Unknown reply on order #{order.id}: #{message}" }
          order
        end
      end
    end

    private

    attr_reader :order, :message

    def classify_intent(normalized)
      return :yes if YES_KEYWORDS.include?(normalized)
      return :no if NO_KEYWORDS.include?(normalized)

      :unknown
    end
  end
end
