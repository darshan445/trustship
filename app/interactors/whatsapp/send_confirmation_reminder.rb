# frozen_string_literal: true

module Whatsapp
  class SendConfirmationReminder
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

        raise_string_error("Order no longer pending") unless order.pending_verification?
        raise_string_error("Confirmation not sent yet") if order.confirmation_sent_at.blank?

        parameters = [ buyer.name, order.product_name ]

        validate_result(
          Whatsapp::SendMessage.execute(
            phone: buyer.phone,
            template_name: Rails.application.credentials.meta[:reminder_template_name],
            parameters: parameters
          )
        )

        order.update!(confirmation_reminder_sent_at: Time.current)
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
