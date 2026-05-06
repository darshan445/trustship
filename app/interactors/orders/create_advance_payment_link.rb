# frozen_string_literal: true

module Orders
  class CreateAdvancePaymentLink
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
        advance_amount = product_advance_amount
        raise_string_error("Advance amount must be greater than 0") unless BigDecimal(advance_amount.to_s).positive?

        result = Razorpay::CreatePaymentLink.execute(
          order_id: order.id,
          amount: advance_amount,
          payment_type: "partial_cod",
          link_purpose: :buyer_advance,
          description: "Advance for Order ##{order.id.to_s.delete('-')[0, 8].upcase} — #{order.product_name}",
          callback_url: advance_callback_url
        )
        validate_result(result)

        {
          payment_link_id: result.data[:payment_link_id],
          payment_link_url: result.data[:payment_link_url],
          amount: BigDecimal(advance_amount.to_s)
        }
      end
    end

    private

    attr_reader :order

    def product_advance_amount
      order.product&.cod_minimum_advance.to_d
    end

    def advance_callback_url
      domain = Rails.application.credentials.dig(:app, :domain).to_s
      raise_string_error("app domain missing in credentials") if domain.blank?

      normalized = domain.start_with?("http://", "https://") ? domain : "https://#{domain}"
      "#{normalized.chomp('/')}/webhooks/razorpay/advance_callback"
    end
  end
end
