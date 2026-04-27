# frozen_string_literal: true

module Orders
  class ProcessRto
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, rto_at:)
      new(order_id: order_id, rto_at: rto_at).execute
    end

    def initialize(order_id:, rto_at:)
      @order_id = order_id
      @rto_at_param = rto_at
    end

    def execute
      execute_log_and_return_open_struct do
        order = Order.includes(:buyer).find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        return order if order.rto?

        raise_string_error("Order is not in shipped state") unless order.shipped?

        buyer = order.buyer

        order.mark_rto!

        rto_ts = parse_rto_at
        order.update!(rto_at: rto_ts)

        buyer.increment_rto_count!

        wa = validate_result_without_raising_error(Whatsapp::SendRtoNotification.execute(order_id: order.id))
        log_error("RTO WhatsApp failed: #{wa.errors}") unless wa.success?

        Rails.logger.info { "Order #{order.id} RTO — buyer #{buyer.phone} rto count updated" }

        order.reload
      end
    end

    private

    attr_reader :order_id, :rto_at_param

    def parse_rto_at
      if rto_at_param.present?
        Time.zone.parse(rto_at_param.to_s)
      else
        Time.current
      end
    rescue ArgumentError, TypeError
      Time.current
    end
  end
end
