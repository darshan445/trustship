# frozen_string_literal: true

module Orders
  class CreateOrder
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(seller_id:, buyer_name:, buyer_phone:, product_name:, amount:, address_line:, city:, state:, pincode:, raw_message: nil, seller_note: nil, payment_type: "full_cod")
      new(
        seller_id: seller_id,
        buyer_name: buyer_name,
        buyer_phone: buyer_phone,
        product_name: product_name,
        amount: amount,
        address_line: address_line,
        city: city,
        state: state,
        pincode: pincode,
        raw_message: raw_message,
        seller_note: seller_note,
        payment_type: payment_type
      ).execute
    end

    def initialize(seller_id:, buyer_name:, buyer_phone:, product_name:, amount:, address_line:, city:, state:, pincode:, raw_message: nil, seller_note: nil, payment_type: "full_cod")
      @seller_id = seller_id
      @buyer_name = buyer_name
      @buyer_phone = buyer_phone
      @product_name = product_name
      @amount = amount
      @address_line = address_line
      @city = city
      @state = state
      @pincode = pincode
      @raw_message = raw_message
      @seller_note = seller_note
      @payment_type = payment_type
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
                :address_line, :city, :state, :pincode, :raw_message, :seller_note, :payment_type

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
      order = Order.create!(
        seller: seller,
        buyer: buyer,
        raw_message: raw_message,
        product_name: product_name,
        amount: amount,
        address_line: address_line,
        city: city,
        state: state,
        pincode: pincode,
        seller_note: seller_note.presence,
        payment_type: normalize_payment_type!
      )
      Orders::RunGateOneJob.perform_later(order.id)
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
  end
end
