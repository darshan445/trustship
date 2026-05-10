# frozen_string_literal: true

module Orders
  class CreateOrder
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(seller_id:, buyer_name:, buyer_phone:, product_name:, amount:, raw_address:, raw_message: nil, seller_note: nil, payment_type: "full_cod", product_id: nil, verification_mode: :whatsapp_automated)
      new(
        seller_id: seller_id,
        buyer_name: buyer_name,
        buyer_phone: buyer_phone,
        product_name: product_name,
        amount: amount,
        raw_address: raw_address,
        raw_message: raw_message,
        seller_note: seller_note,
        payment_type: payment_type,
        product_id: product_id,
        verification_mode: verification_mode
      ).execute
    end

    def initialize(seller_id:, buyer_name:, buyer_phone:, product_name:, amount:, raw_address:, raw_message: nil, seller_note: nil, payment_type: "full_cod", product_id: nil, verification_mode: :whatsapp_automated)
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
      @verification_mode = verification_mode.to_sym
    end

    def execute
      execute_log_and_return_open_struct do
        seller = find_seller!
        buyer = find_or_create_buyer!
        create_order!(seller, buyer)
      end
    end

    private

    attr_reader :seller_id, :buyer_name, :buyer_phone, :product_name, :amount,
                :raw_address, :raw_message, :seller_note, :payment_type, :product_id, :verification_mode

    def find_seller!
      seller = Seller.find_by(id: seller_id)
      raise_string_error("Seller not found") if seller.blank?

      seller
    end

    def find_or_create_buyer!
      raise_string_error("buyer_name is required") if buyer_name.to_s.strip.blank?

      phone = normalize_buyer_phone
      raise_string_error("Invalid buyer phone") unless phone.match?(Buyer::PHONE_REGEX)

      buyer = Buyer.find_by(phone: phone)
      if buyer
        buyer.update!(name: buyer_name) if buyer.name.blank? && buyer_name.present?
        buyer
      else
        Buyer.create!(phone: phone, name: buyer_name)
      end
    end

    def create_order!(seller, buyer)
      raise_string_error("raw_address is required") if raw_address.to_s.strip.blank?

      buyer_address = buyer.buyer_addresses.create!(
        raw_address: raw_address.to_s.strip,
        address_confidence: "pending",
        is_primary: buyer.buyer_addresses.none?
      )

      order = Order.create!(
        seller: seller,
        buyer: buyer,
        buyer_address: buyer_address,
        product: find_product_for_seller(seller),
        raw_message: raw_message,
        product_name: product_name,
        amount: amount,
        seller_note: seller_note.presence,
        payment_type: normalize_payment_type!,
        verification_mode: verification_mode
      )
      Orders::RunGateOneJob.perform_later(order.id) if order.whatsapp_automated?
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

    def normalize_payment_type!
      pt = payment_type.to_s
      unless %w[full_cod full_prepaid].include?(pt)
        raise_string_error("payment_type must be full_cod or full_prepaid at order creation")
      end

      pt
    end

    def find_product_for_seller(seller)
      return nil if product_id.blank?

      seller.products.active.find_by(id: product_id)
    end

  end
end
