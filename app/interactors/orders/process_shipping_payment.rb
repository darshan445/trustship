# frozen_string_literal: true

module Orders
  class ProcessShippingPayment
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, razorpay_payment_id:, amount_paid:)
      new(order_id: order_id, razorpay_payment_id: razorpay_payment_id, amount_paid: amount_paid).execute
    end

    def initialize(order_id:, razorpay_payment_id:, amount_paid:)
      @order_id = order_id
      @razorpay_payment_id = razorpay_payment_id.to_s
      @amount_paid = BigDecimal(amount_paid.to_s)
    end

    def execute
      execute_log_and_return_open_struct do
        raise_string_error("Shipping payment flow is disabled after orders table cleanup")
      end
    end

    private

    attr_reader :order_id, :razorpay_payment_id, :amount_paid
  end
end
