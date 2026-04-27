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

        full_address = "#{order.address_line}, #{order.city}, #{order.state} - #{order.pincode}"
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

        order.update!(confirmation_sent_at: Time.current)
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
