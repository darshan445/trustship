# frozen_string_literal: true

module Orders
  # Razorpay payment link for the full order amount (full_prepaid), buyer as payer.
  # Manual seller flow uses this after confirm; COD partial advances use +CreateAdvancePaymentLink+.
  class CreatePrepaidPaymentLink
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
        raise_string_error("Prepaid link is only for prepaid orders") unless order.full_prepaid?

        amount = BigDecimal(order.amount.to_s)
        raise_string_error("Order amount must be greater than 0") unless amount.positive?

        result = Razorpay::CreatePaymentLink.execute(
          order_id: order.id,
          amount: amount,
          payment_type: "full_prepaid",
          link_purpose: :buyer_advance,
          description: "Prepaid payment for Order ##{order.id.to_s.delete('-')[0, 8].upcase} — #{order.product_name}",
          callback_url: buyer_payment_callback_url
        )
        validate_result(result)

        {
          payment_link_id: result.data[:payment_link_id],
          payment_link_url: result.data[:payment_link_url],
          amount: amount
        }
      end
    end

    private

    attr_reader :order

    def buyer_payment_callback_url
      domain = Rails.application.credentials.dig(:app, :domain).to_s
      raise_string_error("app domain missing in credentials") if domain.blank?

      normalized = domain.start_with?("http://", "https://") ? domain : "https://#{domain}"
      "#{normalized.chomp('/')}/webhooks/razorpay/advance_callback"
    end
  end
end
