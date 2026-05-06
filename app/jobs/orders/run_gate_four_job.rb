# frozen_string_literal: true

module Orders
  class RunGateFourJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      result = Orders::RunGateFour.execute(order_id: order_id)
      return if result.success?

      Rails.logger.error { "RunGateFourJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
