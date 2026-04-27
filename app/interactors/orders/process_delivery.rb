# frozen_string_literal: true

module Orders
  class ProcessDelivery
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, delivered_at:)
      new(order_id: order_id, delivered_at: delivered_at).execute
    end

    def initialize(order_id:, delivered_at:)
      @order_id = order_id
      @delivered_at_param = delivered_at
    end

    def execute
      execute_log_and_return_open_struct do
        order = Order.includes(:buyer).find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        return order if order.delivered?

        raise_string_error("Order is not in shipped state") unless order.shipped?

        buyer = order.buyer

        order.mark_delivered!

        delivered_ts = parse_delivered_at
        order.update!(delivered_at: delivered_ts)

        buyer.increment_successful_delivery_count!

        wa = validate_result_without_raising_error(Whatsapp::SendDeliveredNotification.execute(order_id: order.id))
        log_error("Delivered WhatsApp failed: #{wa.errors}") unless wa.success?

        Rails.logger.info { "Order #{order.id} delivered — buyer #{buyer.phone} delivery count updated" }

        order.reload
      end
    end

    private

    attr_reader :order_id, :delivered_at_param

    def parse_delivered_at
      if delivered_at_param.present?
        Time.zone.parse(delivered_at_param.to_s)
      else
        Time.current
      end
    rescue ArgumentError, TypeError
      Time.current
    end
  end
end
