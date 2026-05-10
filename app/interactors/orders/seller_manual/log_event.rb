# frozen_string_literal: true

module Orders
  module SellerManual
    module LogEvent
      module_function

      def call(order, event_name, metadata = {})
        order.order_events.create!(
          from_state: order.aasm_state,
          to_state: order.aasm_state,
          event_name: event_name,
          triggered_by: "seller",
          metadata: metadata.stringify_keys
        )
      end
    end
  end
end
