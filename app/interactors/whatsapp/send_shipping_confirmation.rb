# frozen_string_literal: true

module Whatsapp
  class SendShippingConfirmation
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
        order = Order.includes(:buyer, :seller).find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        raise_string_error("AWB number not set on order") if order.awb_number.blank?

        buyer = order.buyer
        seller = order.seller
        tracking_url = "https://www.delhivery.com/track/package/#{order.awb_number}"

        parameters = [
          buyer.name,
          seller.business_name,
          order.product_name,
          order.awb_number,
          tracking_url
        ]

        validate_result(
          Whatsapp::SendMessage.execute(
            phone: buyer.phone,
            template_name: Rails.application.credentials.meta[:shipping_confirmation_template_name],
            parameters: parameters
          )
        )

        Rails.logger.info { "Shipping confirmation sent to buyer for order #{order.id}" }

        order.reload
      end
    end

    private

    attr_reader :order_id
  end
end
