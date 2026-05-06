# frozen_string_literal: true

module Orders
  class NotifySellerUnpaidAdvanceJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      order = Order.find_by(id: order_id)
      return if order.nil?

      result = Orders::NotifySellerUnpaidAdvance.execute(order: order)
      return if result.success?

      Rails.logger.error { "NotifySellerUnpaidAdvanceJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
# frozen_string_literal: true

module Orders
  class NotifySellerUnpaidAdvanceJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      order = Order.find_by(id: order_id)
      return if order.blank?

      result = Orders::NotifySellerUnpaidAdvance.execute(order: order)
      return if result.success?

      Rails.logger.error { "NotifySellerUnpaidAdvanceJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
