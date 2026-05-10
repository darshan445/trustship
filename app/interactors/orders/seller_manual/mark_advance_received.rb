# frozen_string_literal: true

module Orders
  module SellerManual
    # Records buyer payment when the seller confirms receipt (offline, UPI, cash, or Razorpay).
    # Creates +OrderAdvancePayment+ when none exists (e.g. Razorpay link step was skipped).
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
          raise_string_error("Confirm the order before recording payment") unless order.confirmed?

          ensure_advance_record!(order)
          advance = order.order_advance_payment
          raise_string_error("No advance payment record found") if advance.blank?
          next order if advance.paid?

          ref = "seller_manual:#{order.id}"

          if order.full_prepaid?
            ApplicationRecord.transaction do
              advance.update!(paid_at: Time.current, razorpay_payment_id: advance.razorpay_payment_id.presence || ref)
              validate_result(
                Orders::ProcessPaymentResult.execute(
                  order_id: order.id,
                  amount_paid: order.amount.to_d,
                  razorpay_payment_id: ref
                )
              )
            end
          elsif order.seller_manual_cod_advance_expected?
            validate_result(
              Orders::ProcessAdvancePayment.execute(order: order, razorpay_payment_id: ref)
            )
          else
            advance.update!(paid_at: Time.current, razorpay_payment_id: advance.razorpay_payment_id.presence || ref)
          end

          LogEvent.call(
            order,
            Orders::SellerManualFlow::MANUAL_ADVANCE_RECEIVED_EVENT,
            { amount: advance.reload.amount.to_s("F") }
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

      def ensure_advance_record!(order)
        return if order.order_advance_payment.present?

        if order.full_prepaid?
          amt = order.amount.to_d
          raise_string_error("Order amount must be greater than 0") unless amt.positive?

          OrderAdvancePayment.create!(
            order: order,
            amount: amt,
            sent_at: Time.current,
            seller_decision: "pending"
          )
        elsif order.seller_manual_cod_advance_expected?
          amt = order.product&.cod_minimum_advance.to_d
          raise_string_error("Product COD minimum advance is not set or is zero") unless amt.positive?

          OrderAdvancePayment.create!(
            order: order,
            amount: amt,
            sent_at: Time.current,
            seller_decision: "pending"
          )
        else
          raise_string_error("No payment applies for this order")
        end

        order.association(:order_advance_payment).reset
      end
    end
  end
end
