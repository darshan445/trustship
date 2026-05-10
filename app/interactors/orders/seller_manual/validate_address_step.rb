# frozen_string_literal: true

module Orders
  module SellerManual
    class ValidateAddressStep
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
          order = find_order!
          ensure_seller_manual!(order)
          raise_string_error("Complete risk scoring first") unless order.seller_manual_risk_completed?
          next order if order.seller_manual_address_completed?

          address = order.buyer_address
          raise_string_error("Address is missing for this order") if address.blank?

          unless address.reusable?
            validate_result_without_raising_error(
              BuyerAddresses::ValidateWithGoogleMaps.execute(buyer_address: address)
            )
            address.reload
          end

          unless deliverable_address_confidence?(address)
            raise_string_error(
              "This address could not be validated as a deliverable location. Update it below and try again."
            )
          end

          LogEvent.call(
            order,
            Orders::SellerManualFlow::MANUAL_ADDRESS_EVENT,
            {
              address_confidence: address.address_confidence.to_s,
              formatted: address.address_formatted.to_s.truncate(500)
            }
          )
          order.reload
        end
      end

      private

      attr_reader :order_id

      def find_order!
        order = Order.find_by(id: order_id)
        raise_string_error("Order not found") if order.blank?

        order
      end

      def ensure_seller_manual!(order)
        raise_string_error("This action is only for manually verified orders") unless order.seller_manual?
      end

      def deliverable_address_confidence?(address)
        address.address_confidence.in?(%w[high medium low])
      end
    end
  end
end
