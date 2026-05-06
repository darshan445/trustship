# frozen_string_literal: true

module Orders
  class SendAdvanceReminderJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      order = Order.find_by(id: order_id)
      return if order.nil?

      result = Orders::SendAdvanceReminder.execute(order: order)
      return if result.success?

      Rails.logger.error { "SendAdvanceReminderJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
# frozen_string_literal: true

module Orders
  class SendAdvanceReminderJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      order = Order.find_by(id: order_id)
      return if order.blank?

      result = Orders::SendAdvanceReminder.execute(order: order)
      return if result.success?

      Rails.logger.error { "SendAdvanceReminderJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
