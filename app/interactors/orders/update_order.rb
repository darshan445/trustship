# frozen_string_literal: true

module Orders
  class UpdateOrder
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(order_id:, seller_id:, buyer_name:, buyer_phone:, product_name:, amount:, raw_address:, raw_message: nil, seller_note: nil, payment_type: "full_cod", product_id: nil)
      new(
        order_id: order_id,
        seller_id: seller_id,
        buyer_name: buyer_name,
        buyer_phone: buyer_phone,
        product_name: product_name,
        amount: amount,
        raw_address: raw_address,
        raw_message: raw_message,
        seller_note: seller_note,
        payment_type: payment_type,
        product_id: product_id
      ).execute
    end

    def initialize(order_id:, seller_id:, buyer_name:, buyer_phone:, product_name:, amount:, raw_address:, raw_message: nil, seller_note: nil, payment_type: "full_cod", product_id: nil)
      @order_id = order_id
      @seller_id = seller_id
      @buyer_name = buyer_name
      @buyer_phone = buyer_phone
      @product_name = product_name
      @amount = amount
      @raw_address = raw_address
      @raw_message = raw_message
      @seller_note = seller_note
      @payment_type = payment_type
      @product_id = product_id
    end

    def execute
      execute_log_and_return_open_struct do
        order = find_order_for_seller!
        raise_string_error("This order can no longer be edited from the dashboard") unless order.editable_by_seller?

        buyer = resolve_buyer!
        new_raw = raw_address.to_s.strip
        raise_string_error("raw_address is required") if new_raw.blank?

        product = find_product_for_seller(order.seller)

        ApplicationRecord.transaction do
          buyer.update!(name: buyer_name.to_s.strip)

          address =
            if buyer.id != order.buyer_id
              buyer.buyer_addresses.create!(
                raw_address: new_raw,
                address_confidence: "pending",
                is_primary: buyer.buyer_addresses.none?
              )
            else
              addr = order.buyer_address
              raise_string_error("Address is missing") if addr.blank?

              old_raw = addr.raw_address.to_s.strip
              if new_raw != old_raw
                addr.update!(raw_address: new_raw, **address_reset_attrs)
              else
                addr.update!(raw_address: new_raw)
              end
              addr
            end

          order.update!(
            buyer: buyer,
            buyer_address: address,
            product: product,
            product_name: product_name.to_s.strip,
            amount: BigDecimal(amount.to_s),
            seller_note: seller_note.presence,
            raw_message: raw_message,
            payment_type: normalize_payment_type!
          )
        end

        order.reload
      end
    end

    private

    attr_reader :order_id, :seller_id, :buyer_name, :buyer_phone, :product_name,
                :amount, :raw_address, :raw_message, :seller_note, :payment_type, :product_id

    def find_order_for_seller!
      order = Order.find_by(id: order_id, seller_id: seller_id)
      raise_string_error("Order not found") if order.blank?

      order
    end

    def normalize_buyer_phone
      digits = buyer_phone.to_s.gsub(/\s+/, "").delete_prefix("+").gsub(/\D/, "")
      if digits.length == 12 && digits.start_with?("91")
        digits[2, 10]
      elsif digits.length == 11 && digits.start_with?("0")
        digits[1, 10]
      elsif digits.length > 10
        digits[-10, 10]
      else
        digits
      end
    end

    def resolve_buyer!
      raise_string_error("buyer_name is required") if buyer_name.to_s.strip.blank?

      phone = normalize_buyer_phone
      raise_string_error("Invalid buyer phone") unless phone.match?(Buyer::PHONE_REGEX)

      buyer = Buyer.find_by(phone: phone)
      if buyer
        buyer.update!(name: buyer_name.to_s.strip) if buyer_name.present?
        buyer
      else
        Buyer.create!(phone: phone, name: buyer_name.to_s.strip)
      end
    end

    def normalize_payment_type!
      pt = payment_type.to_s
      unless %w[full_cod full_prepaid].include?(pt)
        raise_string_error("payment_type must be full_cod or full_prepaid")
      end

      pt
    end

    def find_product_for_seller(seller)
      return nil if product_id.blank?

      seller.products.active.find_by(id: product_id)
    end

    def address_reset_attrs
      {
        validated_at: nil,
        address_confidence: "pending",
        address_formatted: nil,
        latitude: nil,
        longitude: nil
      }
    end
  end
end
