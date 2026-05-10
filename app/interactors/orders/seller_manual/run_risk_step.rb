# frozen_string_literal: true

module Orders
  module SellerManual
    class RunRiskStep
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
          next order if order.order_events.exists?(event_name: Orders::SellerManualFlow::MANUAL_RISK_EVENT)

          risk_data = validate_result(Buyers::CalculateRiskScore.execute(buyer_id: order.buyer_id)).data

          if risk_data.risk_level == "high"
            if order.pending_verification? && order.may_mark_high_risk?
              validate_result(Orders::MarkHighRisk.execute(order_id: order.id))
              order.reload
            end
          end

          LogEvent.call(
            order,
            Orders::SellerManualFlow::MANUAL_RISK_EVENT,
            { risk_level: risk_data.risk_level.to_s }
          )
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

      def ensure_seller_manual!(order)
        raise_string_error("This action is only for manually verified orders") unless order.seller_manual?
      end
    end
  end
end
