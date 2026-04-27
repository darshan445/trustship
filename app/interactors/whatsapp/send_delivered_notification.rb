# frozen_string_literal: true

module Whatsapp
  class SendDeliveredNotification
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

        buyer = order.buyer
        seller = order.seller
        parameters = [
          buyer.name,
          order.product_name,
          seller.business_name
        ]

        validate_result(
          Whatsapp::SendMessage.execute(
            phone: buyer.phone,
            template_name: Rails.application.credentials.meta[:delivered_template_name],
            parameters: parameters
          )
        )

        Rails.logger.info { "Delivery notification sent to buyer for order #{order.id}" }

        order.reload
      end
    end

    private

    attr_reader :order_id
  end
end
