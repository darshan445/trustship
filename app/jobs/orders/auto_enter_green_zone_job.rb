# frozen_string_literal: true

module Orders
  class AutoEnterGreenZoneJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      result = Orders::EnterGreenZoneAsCod.execute(order_id: order_id)

      return if result.success?

      err = result.errors.to_s
      if err.match?(/green_zone|shipped|delivered|rto/i)
        Rails.logger.info { "AutoEnterGreenZoneJob: order #{order_id} already advanced (#{err}) — skipped" }
        return
      end

      Rails.logger.error { "AutoEnterGreenZoneJob failed for order #{order_id}: #{err}" }
    end
  end
end
