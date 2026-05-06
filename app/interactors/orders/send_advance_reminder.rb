# frozen_string_literal: true

module Orders
  class SendAdvanceReminder
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:, force: false)
      new(order: order, force: force).execute
    end

    def initialize(order:, force:)
      @order = order
      @force = force
    end

    def execute
      execute_log_and_return_open_struct do
        advance_payment = order.order_advance_payment
        return order if advance_payment.nil? || advance_payment.paid? || (advance_payment.reminded? && !force)

        parameters = [
          order.buyer.name,
          order.product_name,
          "₹#{order.amount}",
          "₹#{advance_payment.amount}",
          advance_payment.razorpay_payment_link_url,
          order.seller.business_name
        ]

        validate_result(
          Whatsapp::SendTemplateMessage.execute(
            to: order.buyer.phone,
            template_name: Rails.application.credentials.dig(:meta, :prepaid_incentive_template_name),
            parameters: parameters
          )
        )

        advance_payment.update!(reminded_at: Time.current)
        log_gate_event("advance_reminder_sent", reminded_at: advance_payment.reminded_at)
        Orders::NotifySellerUnpaidAdvanceJob.set(wait: 4.hours).perform_later(order.id)

        order
      end
    end

    private

    attr_reader :order, :force

    def log_gate_event(name, metadata)
      order.order_events.create!(
        from_state: order.aasm_state,
        to_state: order.aasm_state,
        event_name: name,
        triggered_by: "system",
        metadata: metadata
      )
    end
  end
end
# frozen_string_literal: true

module Orders
  class SendAdvanceReminder
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order:)
      new(order: order).execute
    end

    def initialize(order:)
      @order = order
    end

    def execute
      execute_log_and_return_open_struct do
        advance_payment = order.order_advance_payment
        return order if advance_payment.nil? || advance_payment.paid? || advance_payment.reminded?

        parameters = [
          order.buyer.name,
          order.product_name,
          "₹#{order.amount}",
          "₹#{advance_payment.amount}",
          advance_payment.razorpay_payment_link_url,
          order.seller.business_name
        ]

        whatsapp_result = Whatsapp::SendTemplateMessage.execute(
          to: order.buyer.phone,
          template_name: Rails.application.credentials.dig(:meta, :prepaid_incentive_template_name),
          parameters: parameters
        )
        raise_string_error(whatsapp_result.errors.to_s) unless whatsapp_result.success?

        advance_payment.update!(reminded_at: Time.current)
        log_event(order, "advance_reminder_sent", { reminded_at: Time.current })
        Orders::NotifySellerUnpaidAdvanceJob.set(wait: 4.hours).perform_later(order.id)
        advance_payment
      end
    end

    private

    attr_reader :order
  end
end
