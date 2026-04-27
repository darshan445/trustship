# frozen_string_literal: true

module Whatsapp
  class SendOrderAcknowledgement
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, phone:)
      new(order_id: order_id, phone: phone).execute
    end

    def initialize(order_id:, phone:)
      @order_id = order_id
      @phone = phone
    end

    def execute
      execute_log_and_return_open_struct do
        order = Order.includes(:seller, :buyer).find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        template_name = Rails.application.credentials.meta[:order_acknowledgement_template_name].to_s
        raise_string_error("Order acknowledgement template not configured") if template_name.blank?

        parameters = [
          order.buyer&.name.presence || "there",
          order.product_name,
          order.seller.business_name
        ]

        validate_result(
          Whatsapp::SendMessage.execute(
            phone: phone,
            template_name: template_name,
            parameters: parameters
          )
        )

        Rails.logger.info { "Order acknowledgement sent to #{phone} for order #{order.id}" }

        OpenStruct.new(sent: true)
      end
    end

    private

    attr_reader :order_id, :phone
  end
end
