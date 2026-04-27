# frozen_string_literal: true

module Orders
  class RunGateOne
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
        raise_string_error("Order must be pending verification for Gate 1") unless order.pending_verification?

        pin = validate_result(Delhivery::ValidatePincode.execute(pincode: order.pincode)).data

        if !pin.valid || !pin.serviceable
          Rails.logger.info { "Gate 1 failed for order #{order.id}" }
          validate_result(
            Orders::MarkUndeliverable.execute(
              order_id: order.id,
              reason: "Pincode invalid or unserviceable"
            )
          )
          order.reload
        else
          attrs = { pincode_verified_at: Time.current }
          attrs[:city] = pin.city if pin.city.present? && order.city.blank?
          attrs[:state] = pin.state if pin.state.present? && order.state.blank?
          order.update!(attrs)
          Rails.logger.info { "Gate 1 passed for order #{order.id}" }
          validate_result(Orders::RunGateTwo.execute(order_id: order.id))
          order.reload
        end

        order
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
