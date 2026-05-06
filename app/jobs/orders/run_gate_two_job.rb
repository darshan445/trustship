# frozen_string_literal: true

module Orders
  class RunGateTwoJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      result = Orders::RunGateTwo.execute(order_id: order_id)
      return if result.success?

      Rails.logger.error { "Orders::RunGateTwoJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
