# frozen_string_literal: true

module Orders
  class RunGateOne
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
        raise_string_error("Order must be pending verification for Gate 1") unless order.pending_verification?

        raw_address = build_raw_address(order)
        if raw_address.blank?
          log_gate_event(order, "gate_1_failed", reason: "No address provided")
          Orders::RunGateTwoJob.perform_later(order.id)
          next order.reload
        end

        find_result = validate_result(BuyerAddresses::FindOrCreate.execute(buyer: order.buyer, raw_address: raw_address))
        buyer_address = find_result.data[:buyer_address]

        unless find_result.data[:reused]
          validate_result_without_raising_error(
            BuyerAddresses::ValidateWithGoogleMaps.execute(buyer_address: buyer_address)
          )
        end

        order.update!(buyer_address_id: buyer_address.id)
        order.reload

        log_gate_event(
          order,
          "gate_1_completed",
          confidence: order.buyer_address&.address_confidence,
          formatted: order.buyer_address&.address_formatted,
          reused: find_result.data[:reused]
        )

        Orders::RunGateTwoJob.perform_later(order.id)
        order.reload
      end
    end

    private

    attr_reader :order_id

    def find_order!
      order = Order.find_by(id: order_id)
      raise_string_error("Order not found") if order.blank?

      order
    end

    def build_raw_address(order)
      order.buyer_address&.raw_address.to_s.strip
    end

    def log_gate_event(order, event_name, metadata)
      order.order_events.create!(
        from_state: order.aasm_state,
        to_state: order.aasm_state,
        event_name: event_name,
        triggered_by: "system",
        metadata: metadata
      )
    end
  end
end
