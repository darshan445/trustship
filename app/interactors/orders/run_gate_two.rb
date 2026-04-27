# frozen_string_literal: true

module Orders
  class RunGateTwo
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
        raise_string_error("Order must be pending verification for Gate 2") unless order.pending_verification?

        risk_data = validate_result(Buyers::CalculateRiskScore.execute(buyer_id: order.buyer_id)).data

        if risk_data.risk_level == "high"
          flagged = validate_result(Orders::MarkHighRisk.execute(order_id: order.id)).data
          flagged.update!(buyer_risk_assessed_at: Time.current)
          Rails.logger.info { "Gate 2 flagged order #{order.id} as high risk" }
          flagged.reload
        else
          Rails.logger.info { "Gate 2 passed for order #{order.id}, buyer risk: #{risk_data.risk_level}" }
          order.update!(buyer_risk_assessed_at: Time.current)
          validate_result(Orders::RunGateThree.execute(order_id: order.id))
          order.reload
        end
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
