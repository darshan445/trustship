# frozen_string_literal: true

module Whatsapp
  class SendPrepaidIncentive
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
        buyer = order.buyer
        seller = order.seller

        raise_string_error("Order must be confirmed for Gate 4") unless order.confirmed?

        suggested_advance = [ order.amount * BigDecimal("0.1"), BigDecimal("100") ].max.round(2)

        link_result = validate_result(
          Razorpay::CreatePaymentLink.execute(
            order_id: order.id,
            amount: order.amount,
            payment_type: "full_prepaid"
          )
        ).data

        parameters = [
          buyer.name,
          order.product_name,
          "₹#{order.amount}",
          "₹#{suggested_advance}",
          link_result.payment_link_url,
          seller.business_name
        ]

        validate_result(
          Whatsapp::SendMessage.execute(
            phone: buyer.phone,
            template_name: Rails.application.credentials.meta[:prepaid_incentive_template_name],
            parameters: parameters
          )
        )

        order.order_events.create!(
          from_state: order.aasm_state,
          to_state: order.aasm_state,
          event_name: "prepaid_incentive_sent",
          triggered_by: "system",
          metadata: {}
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
  end
end
