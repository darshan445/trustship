# frozen_string_literal: true

module Orders
  class CreateShippingPaymentLink
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:)
      new(order: order).execute
    end

    def initialize(order:)
      @order = order
    end

    def execute
      execute_log_and_return_open_struct do
        raise_string_error("Order is required") if order.blank?

        current_order = Order.find(order.id)
        raise_string_error("Order must be in green zone") unless current_order.green_zone?
        raise_string_error("Shipping is already paid for this order") if current_order.shipping_payment_status == "paid"

        if current_order.shipping_payment_link_url.present? && current_order.shipping_amount.present?
          return OpenStruct.new(amount: current_order.shipping_amount, payment_link_url: current_order.shipping_payment_link_url)
        end

        amount = validate_result(Orders::CalculateShippingCost.execute(order: current_order)).data


        short = current_order.id.to_s.delete("-")[0, 8].upcase
        desc = "Shipping for Order ##{short}"

        result = Razorpay::CreatePaymentLink.execute(
          order_id: current_order.id,
          amount: amount,
          payment_type: "shipping",
          link_purpose: :seller_shipping,
          description: desc,
          callback_url: nil
        )
        raise_string_error(result.errors.to_s) unless result.success?

        current_order.reload
        OpenStruct.new(amount: amount, payment_link_url: current_order.shipping_payment_link_url)
      end
    end

    private

    attr_reader :order
  end
end
