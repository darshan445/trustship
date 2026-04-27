# frozen_string_literal: true

module Orders
  class CreateOrderFromWhatsapp
    include ExecuteMethodHelper
    include LogHelper
    include PhoneHelper

    def self.execute(phone:, message:)
      new(phone: phone, message: message).execute
    end

    def initialize(phone:, message:)
      @phone = phone
      @message = message
    end

    def execute
      execute_log_and_return_open_struct do
        normalized_phone = normalize_phone(phone)
        raise_string_error("Phone is required") if normalized_phone.blank?
        raise_string_error("Message cannot be blank") if message.to_s.strip.blank?

        shop_code = message.strip.split(" ").first&.upcase
        raise_string_error("Message cannot be blank") if shop_code.blank?

        seller = Seller.find_by(shop_code: shop_code)
        raise_string_error("Unknown shop code: #{shop_code}") if seller.blank?

        clean_message = message.split(" ").drop(1).join(" ").strip
        raise_string_error("Message has no order details") if clean_message.blank?

        parsed = validate_result(Orders::ParseWhatsappMessage.execute(raw_message: clean_message)).data

        buyer_phone = normalize_phone(parsed.buyer_phone).presence || normalized_phone
        raise_string_error("Invalid buyer phone") unless buyer_phone.match?(Buyer::PHONE_REGEX)

        product_name = parsed.product_name.to_s.strip
        raise_string_error("Could not extract product from message") if product_name.blank?

        amount = parsed.amount.presence || 0
        payment_type = parsed.is_cod ? "full_cod" : "full_prepaid"

        order = validate_result(
          Orders::CreateOrder.execute(
            seller_id: seller.id,
            buyer_name: parsed.buyer_name.presence || "WhatsApp Buyer",
            buyer_phone: buyer_phone,
            product_name: product_name,
            amount: amount,
            address_line: parsed.address_line.presence || "Address pending verification",
            city: parsed.city.presence || "Pending",
            state: parsed.state.presence || "Pending",
            pincode: parsed.pincode.to_s.strip.match?(/\A\d{6}\z/) ? parsed.pincode.to_s.strip : "000000",
            raw_message: message,
            payment_type: payment_type
          )
        ).data

        validate_result_without_raising_error(
          Whatsapp::SendOrderAcknowledgement.execute(order_id: order.id, phone: buyer_phone)
        )

        Rails.logger.info do
          "Order #{order.id} created from WhatsApp for seller #{shop_code} — buyer #{buyer_phone}"
        end

        order
      end
    end

    private

    attr_reader :phone, :message
  end
end
