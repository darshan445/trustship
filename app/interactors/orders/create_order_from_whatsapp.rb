# frozen_string_literal: true

module Orders
  class CreateOrderFromWhatsapp
    include ExecuteMethodHelper
    include LogHelper
    include PhoneHelper

    def self.execute(seller_id:, buyer_phone:, message:)
      new(seller_id: seller_id, buyer_phone: buyer_phone, message: message).execute
    end

    def initialize(seller_id:, buyer_phone:, message:)
      @seller_id = seller_id
      @buyer_phone = buyer_phone
      @message = message
    end

    def execute
      execute_log_and_return_open_struct do
        seller = Seller.find_by(id: seller_id)
        raise_string_error("Seller not found") if seller.blank?

        normalized_buyer = normalize_phone(buyer_phone)
        raise_string_error("Invalid buyer phone") if normalized_buyer.blank?
        raise_string_error("Invalid buyer phone") unless normalized_buyer.match?(Buyer::PHONE_REGEX)
        raise_string_error("Message cannot be blank") if message.to_s.strip.blank?

        parsed = validate_result(Orders::ParseWhatsappMessage.execute(raw_message: message, seller: seller)).data

        resolved_phone = normalize_phone(parsed.buyer_phone).presence || normalized_buyer
        raise_string_error("Invalid buyer phone") unless resolved_phone.match?(Buyer::PHONE_REGEX)

        product_name = parsed.product_name.to_s.strip
        raise_string_error("Could not extract product from message") if product_name.blank?

        amount = parsed.amount.presence || 0
        payment_type = parsed.is_cod ? "full_cod" : "full_prepaid"
        raw_address = [
          parsed.address_line,
          parsed.city,
          parsed.state,
          parsed.pincode
        ].map { |v| v.to_s.strip.presence }.compact.join(", ")
        raw_address = "Address pending verification" if raw_address.blank?

        order = validate_result(
          Orders::CreateOrder.execute(
            seller_id: seller.id,
            buyer_name: parsed.buyer_name.presence || "WhatsApp Buyer",
            buyer_phone: resolved_phone,
            product_name: product_name,
            product_id: parsed.matched_product_id,
            amount: amount,
            raw_address: raw_address,
            raw_message: message,
            seller_note: parsed.special_instructions.to_s.presence,
            payment_type: payment_type
          )
        ).data

        validate_result_without_raising_error(
          Whatsapp::SendOrderAcknowledgement.execute(order_id: order.id, phone: resolved_phone)
        )

        Rails.logger.info do
          "Order #{order.id} created from WhatsApp for seller #{seller.id} — buyer #{resolved_phone}"
        end

        order
      end
    end

    private

    attr_reader :seller_id, :buyer_phone, :message
  end
end
