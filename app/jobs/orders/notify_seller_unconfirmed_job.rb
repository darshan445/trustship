# frozen_string_literal: true

module Orders
  class NotifySellerUnconfirmedJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      order = Order.find_by(id: order_id)
      return if order.blank?

      result = Orders::NotifySellerUnconfirmed.execute(order: order)
      return if result.success?

      Rails.logger.error { "NotifySellerUnconfirmedJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
