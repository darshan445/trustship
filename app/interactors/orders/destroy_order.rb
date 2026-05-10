# frozen_string_literal: true

module Orders
  class DestroyOrder
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
        order = find_order_for_seller!
        raise_string_error("This order cannot be deleted from the dashboard") unless order.deletable_by_seller?

        order.destroy!
        true
      end
    end

    private

    attr_reader :order_id, :seller_id

    def find_order_for_seller!
      order = Order.find_by(id: order_id, seller_id: seller_id)
      raise_string_error("Order not found") if order.blank?

      order
    end
  end
end
