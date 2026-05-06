# frozen_string_literal: true

module Whatsapp
  class SendOrderConfirmation
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

        full_address = order.buyer_address&.address_formatted.presence || order.buyer_address&.raw_address.to_s
        amount_string =
          if order.full_prepaid?
            "₹#{order.amount} Prepaid"
          else
            "₹#{order.amount} COD"
          end

        parameters = [
          buyer.name,
          seller.business_name,
          order.product_name,
          full_address,
          amount_string
        ]

        validate_result(
          Whatsapp::SendMessage.execute(
            phone: buyer.phone,
            template_name: Rails.application.credentials.meta[:confirmation_template_name],
            parameters: parameters
          )
        )

        order.order_events.create!(
          from_state: order.aasm_state,
          to_state: order.aasm_state,
          event_name: "confirmation_sent",
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
