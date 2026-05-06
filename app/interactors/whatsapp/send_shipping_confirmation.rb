# frozen_string_literal: true

module Whatsapp
  class SendShippingConfirmation
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
        raise_string_error("Shipping confirmation flow is disabled after orders table cleanup")
      end
    end

    private

    attr_reader :order_id
  end
end
