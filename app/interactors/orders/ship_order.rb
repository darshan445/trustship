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
        order = find_order_for_seller!
        seller = order.seller

        raise_string_error("Order is not in green zone") unless order.green_zone?
        unless order.shipping_payment_status == "paid"
          raise_string_error("Pay the shipping charge before creating a Delhivery shipment")
        end
        unless seller.pickup_address_complete?
          raise_string_error("Please add your pickup address before shipping")
        end

        shipment = validate_result(Delhivery::CreateShipment.execute(order_id: order.id)).data

        order.update!(
          awb_number: shipment.awb_number,
          delhivery_shipment_id: shipment.delhivery_shipment_id,
          shipped_at: Time.current
        )
        order.reload

        order.ship!

        label_result = Delhivery::FetchShippingLabel.execute(order_id: order.id)
        unless label_result.success?
          Rails.logger.error { "Label fetch failed for order #{order.id}: #{label_result.errors}" }
        end

        whatsapp_result = validate_result_without_raising_error(
          Whatsapp::SendShippingConfirmation.execute(order_id: order.id)
        )
        unless whatsapp_result.success?
          Rails.logger.error { "Shipping confirmation WhatsApp failed for order #{order.id}: #{whatsapp_result.errors}" }
        end

        Rails.logger.info { "Order #{order.id} shipped successfully — AWB: #{shipment.awb_number}" }

        order.reload
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
