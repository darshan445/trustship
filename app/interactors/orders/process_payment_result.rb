# frozen_string_literal: true

module Orders
  class ProcessPaymentResult
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, amount_paid:, razorpay_payment_id:)
      new(order_id: order_id, amount_paid: amount_paid, razorpay_payment_id: razorpay_payment_id).execute
    end

    def initialize(order_id:, amount_paid:, razorpay_payment_id:)
      @order_id = order_id
      @amount_paid = BigDecimal(amount_paid.to_s)
      @razorpay_payment_id = razorpay_payment_id.to_s
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order!

        if order.green_zone? || order.shipped? || order.delivered? || order.rto?
          next order
        end

        unless order.confirmed?
          raise_string_error("Cannot process payment from state #{order.aasm_state}")
        end

        payment_type_sym = determine_payment_type(order)
        is_prepaid_flag = (payment_type_sym == :full_prepaid)

        validate_result(
          Orders::EnterGreenZone.execute(
            order_id: order.id,
            is_prepaid: is_prepaid_flag,
            payment_reference: razorpay_payment_id.presence
          )
        )

        order.reload

        advance =
          if payment_type_sym == :partial_cod
            amount_paid
          else
            nil
          end

        order.update!(
          payment_type: payment_type_sym,
          advance_amount: advance
        )

        Rails.logger.info do
          "Order #{order.id} payment processed — type: #{payment_type_sym}, amount: #{amount_paid}"
        end

        order.reload
      end
    end

    private

    attr_reader :order_id, :amount_paid, :razorpay_payment_id

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end

    def determine_payment_type(order)
      paid_paise = (amount_paid * 100).round
      total_paise = (order.amount * 100).round

      if paid_paise >= total_paise
        :full_prepaid
      elsif paid_paise.positive?
        :partial_cod
      else
        raise_string_error("Invalid amount paid for payment processing")
      end
    end
  end
end
