# frozen_string_literal: true

module Orders
  class CreateOrderFromWhatsappJob < ApplicationJob
    include LogHelper

    queue_as :default

    def perform(phone:, message:)
      result = Orders::CreateOrderFromWhatsapp.execute(phone: phone, message: message)

      if result.success?
        Rails.logger.info { "WhatsApp order created: order_id=#{result.data.id} phone=#{phone}" }
        return
      end

      Rails.logger.error { "WhatsApp order creation failed for #{phone}: #{result.errors}" }

      template_name = Rails.application.credentials.meta[:order_failed_template_name].to_s
      return if template_name.blank?

      validate_result_without_raising_error(
        Whatsapp::SendMessage.execute(
          phone: phone,
          template_name: template_name,
          parameters: [ "there" ]
        )
      )
    end
  end
end
