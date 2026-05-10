# frozen_string_literal: true

module Orders
  module SellerManual
    # Creates a Razorpay payment link and persists +OrderAdvancePayment+ without sending
    # WhatsApp (dashboard / manual flow). Automated flow keeps using +SendAdvancePaymentRequest+.
    class CreateAdvanceLink
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
          raise_string_error("Confirm the order before generating a payment link") unless order.confirmed?

          next order if order.order_advance_payment&.paid?
          next order if order.order_events.exists?(event_name: Orders::SellerManualFlow::MANUAL_ADVANCE_LINK_EVENT)

          unless order.full_cod?
            LogEvent.call(order, Orders::SellerManualFlow::MANUAL_ADVANCE_LINK_EVENT, { "skipped" => true, "reason" => "not_cod" })
            next order.reload
          end

          advance_amount = order.product&.cod_minimum_advance.to_d
          unless advance_amount.positive?
            LogEvent.call(order, Orders::SellerManualFlow::MANUAL_ADVANCE_LINK_EVENT, { "skipped" => true, "reason" => "no_advance_on_product" })
            next order.reload
          end

          link_result = validate_result(Orders::CreateAdvancePaymentLink.execute(order: order))
          advance = order.order_advance_payment || OrderAdvancePayment.new(order: order)
          advance.update!(
            amount: link_result.data[:amount],
            razorpay_payment_link_id: link_result.data[:payment_link_id],
            razorpay_payment_link_url: link_result.data[:payment_link_url],
            sent_at: Time.current,
            seller_decision: "pending",
            seller_decided_at: nil
          )

          LogEvent.call(
            order,
            Orders::SellerManualFlow::MANUAL_ADVANCE_LINK_EVENT,
            {
              "amount" => advance.amount.to_s("F"),
              "payment_link_url" => advance.razorpay_payment_link_url.to_s
            }
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
