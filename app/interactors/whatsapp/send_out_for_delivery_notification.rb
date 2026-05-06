# frozen_string_literal: true

module Whatsapp
  class SendOutForDeliveryNotification
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, agent_name:, agent_phone:)
      new(order_id: order_id, agent_name: agent_name, agent_phone: agent_phone).execute
    end

    def initialize(order_id:, agent_name:, agent_phone:)
      @order_id = order_id
      @agent_name = agent_name
      @agent_phone = agent_phone
    end

    def execute
      execute_log_and_return_open_struct do
        order = Order.includes(:buyer).find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        buyer = order.buyer
        parameters = [
          buyer.name,
          order.product_name,
          agent_name.to_s.presence || "Delivery Agent",
          agent_phone.to_s.presence || "Contact delivery support"
        ]

        validate_result(
          Whatsapp::SendMessage.execute(
            phone: buyer.phone,
            template_name: Rails.application.credentials.meta[:out_for_delivery_template_name],
            parameters: parameters
          )
        )

        Rails.logger.info { "OFD notification sent to buyer for order #{order.id}" }

        order.reload
      end
    end

    private

    attr_reader :order_id, :agent_name, :agent_phone
  end
end
