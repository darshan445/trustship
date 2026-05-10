# frozen_string_literal: true

module Orders
  module SellerManual
    # Records COD advance as paid when the seller confirms receipt (e.g. Razorpay
    # webhook not wired yet, or offline collection). Does not replace webhook processing.
    class MarkAdvanceReceived
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

          advance = order.order_advance_payment
          raise_string_error("Generate the advance payment link first") if advance.blank?
          raise_string_error("This advance is already marked as paid") if advance.paid?

          advance.update!(
            paid_at: Time.current,
            razorpay_payment_id: advance.razorpay_payment_id.presence || "seller_manual:#{order.id}"
          )

          LogEvent.call(
            order,
            Orders::SellerManualFlow::MANUAL_ADVANCE_RECEIVED_EVENT,
            { amount: advance.amount.to_s("F") }
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
