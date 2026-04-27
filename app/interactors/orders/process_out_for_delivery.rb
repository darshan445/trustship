# frozen_string_literal: true

module Orders
  class ProcessOutForDelivery
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
        order = Order.find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        return order unless order.shipped?

        wa = validate_result_without_raising_error(
          Whatsapp::SendOutForDeliveryNotification.execute(
            order_id: order.id,
            agent_name: agent_name,
            agent_phone: agent_phone
          )
        )
        log_error("OFD WhatsApp failed: #{wa.errors}") unless wa.success?

        state = order.aasm_state.to_s
        order.order_events.create!(
          from_state: state,
          to_state: state,
          event_name: "out_for_delivery",
          triggered_by: "system",
          metadata: { agent_name: agent_name, agent_phone: agent_phone }.stringify_keys
        )

        Rails.logger.info { "OFD event processed for order #{order.id}" }

        order.reload
      end
    end

    private

    attr_reader :order_id, :agent_name, :agent_phone
  end
end
