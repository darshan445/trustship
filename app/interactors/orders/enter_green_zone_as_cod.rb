# frozen_string_literal: true

module Orders
  class EnterGreenZoneAsCod
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

        if order.green_zone? || order.shipped? || order.delivered? || order.rto?
          return order
        end

        unless order.confirmed?
          raise_string_error("Cannot enter green zone from #{order.aasm_state}")
        end

        validate_result(
          Orders::EnterGreenZone.execute(
            order_id: order.id,
            is_prepaid: false,
            payment_reference: nil
          )
        )

        order.reload
        order.update!(payment_type: :full_cod, advance_amount: nil)

        Rails.logger.info { "Order #{order.id} entered green zone as full COD — no payment received" }

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
