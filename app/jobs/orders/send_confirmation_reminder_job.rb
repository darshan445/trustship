# frozen_string_literal: true

module Orders
  class SendConfirmationReminderJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      result = Whatsapp::SendConfirmationReminder.execute(order_id: order_id)

      return if result.success?

      if result.errors.to_s == "Order no longer pending"
        Rails.logger.info { "SendConfirmationReminderJob: order #{order_id} no longer pending, reminder skipped" }
        return
      end

      Rails.logger.error { "SendConfirmationReminderJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
