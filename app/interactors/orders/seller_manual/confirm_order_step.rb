# frozen_string_literal: true

module Orders
  module SellerManual
    class ConfirmOrderStep
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
          ensure_seller_manual!(order)
          raise_string_error("Complete risk scoring first") unless order.seller_manual_risk_completed?
          raise_string_error("Verify the delivery address successfully before confirming.") unless order.seller_manual_address_completed?
          raise_string_error("Order cannot be confirmed in its current state") unless order.may_confirm?

          validate_result(Orders::ConfirmOrder.execute(order_id: order.id, triggered_by: "seller"))
          Order.find(order_id).reload
        end
      end

      private

      attr_reader :order_id

      def find_order!
        order = Order.find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        order
      end

      def ensure_seller_manual!(order)
        raise_string_error("This action is only for manually verified orders") unless order.seller_manual?
      end
    end
  end
end
