# frozen_string_literal: true

module Orders
  class ShipOrder
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, seller_id:)
      new(order_id: order_id, seller_id: seller_id).execute
    end

    def initialize(order_id:, seller_id:)
      @order_id = order_id
      @seller_id = seller_id
    end

    def execute
      execute_log_and_return_open_struct do
        raise_string_error("Shipping integration is disabled after orders table cleanup")
      end
    end

    private

    attr_reader :order_id, :seller_id

    def find_order_for_seller!; end
  end
end
