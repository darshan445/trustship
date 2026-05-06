# frozen_string_literal: true

module Orders
  class RunGateThreeJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      result = Orders::RunGateThree.execute(order_id: order_id)
      return if result.success?

      Rails.logger.error { "RunGateThreeJob failed for order #{order_id}: #{result.errors}" }
    end
  end
end
