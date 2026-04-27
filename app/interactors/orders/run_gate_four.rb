# frozen_string_literal: true

module Orders
  class RunGateFour
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
        raise_string_error("Order must be confirmed for Gate 4") unless order.confirmed?

        validate_result(Whatsapp::SendPrepaidIncentive.execute(order_id: order.id))

        Orders::AutoEnterGreenZoneJob.set(wait: 30.minutes).perform_later(order.id)

        Rails.logger.info { "Gate 4 started for order #{order.id} — payment options sent to buyer" }

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
