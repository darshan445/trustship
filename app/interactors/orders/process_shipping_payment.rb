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
        order = Order.find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        if order.shipping_payment_status == "paid"
          order
        else
          raise_string_error("Order is not awaiting shipping payment") unless order.shipping_payment_status == "pending"

          order.update!(
            shipping_payment_id: razorpay_payment_id,
            shipping_paid_at: Time.current,
            shipping_payment_status: "paid"
          )

          Rails.logger.info { "Order #{order.id} shipping paid ₹#{amount_paid} (#{razorpay_payment_id})" }

          ship_result = Orders::ShipOrder.execute(order_id: order.id, seller_id: order.seller_id)
          unless ship_result.success?
            Rails.logger.error do
              "Shipping paid for order #{order.id} but ShipOrder failed: #{ship_result.errors}. Seller can retry Ship Now."
            end
          end

          order.reload
        end
      end
    end

    private

    attr_reader :order_id, :razorpay_payment_id, :amount_paid
  end
end
