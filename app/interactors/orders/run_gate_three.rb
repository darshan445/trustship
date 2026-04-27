# frozen_string_literal: true

module Orders
  class RunGateThree
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:)
      new(order_id: order_id).execute
    end

    def initialize(order_id:)
      @order_id = order_id
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order!
        raise_string_error("Order must be pending verification for Gate 3") unless order.pending_verification?

        validate_result(Whatsapp::SendOrderConfirmation.execute(order_id: order.id))

        Orders::SendConfirmationReminderJob.set(wait: 4.hours).perform_later(order.id)

        Rails.logger.info { "Gate 3 started for order #{order.id} — confirmation sent to buyer" }

        order.reload
      end
    end

    private

    attr_reader :order_id

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end
  end
end
