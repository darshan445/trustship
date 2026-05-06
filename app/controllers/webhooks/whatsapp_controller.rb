# frozen_string_literal: true

module Webhooks
  class WhatsappController < ActionController::Base
    include PhoneHelper

    skip_forgery_protection

    def verify
      mode = params["hub.mode"]
      token = params["hub.verify_token"]
      challenge = params["hub.challenge"]

      if mode.to_s == "subscribe" && token.to_s == Rails.application.credentials.meta[:webhook_verify_token].to_s
        render plain: challenge.to_s, status: :ok
      else
        head :forbidden
      end
    end

    def receive
      raw_post = request.raw_post

      unless meta_signature_valid?(raw_post)
        head :forbidden
        return
      end

      payload = JSON.parse(raw_post)
      value = payload.dig("entry", 0, "changes", 0, "value")
      messages = value&.dig("messages")
      metadata = value&.dig("metadata") || {}

      if messages.blank?
        head :ok
        return
      end

      to_phone = normalize_phone(metadata["display_phone_number"].presence)
      if to_phone.blank?
        Rails.logger.warn { "WhatsApp webhook: could not normalize receiving phone #{metadata['display_phone_number'].inspect}" }
        head :ok
        return
      end

      seller = Seller.find_by(phone: to_phone)
      unless seller
        head :ok
        return
      end

      Array(messages).each do |msg|
        process_incoming_message(msg, seller)
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error { "WhatsApp webhook JSON parse error: #{e.message}" }
      head :ok
    rescue StandardError => e
      Rails.logger.error { "WhatsApp webhook error: #{e.class}: #{e.message}" }
      head :ok
    end

    private

    def process_incoming_message(msg, seller)
      return unless msg.is_a?(Hash)
      return unless msg["type"].to_s == "text"

      body = msg.dig("text", "body")
      return if body.blank?

      from_raw = msg["from"].to_s
      from_phone = normalize_phone(from_raw)
      if from_phone.blank?
        Rails.logger.warn { "WhatsApp webhook: could not normalize sender phone #{from_raw.inspect}" }
        return
      end

      if from_phone == seller.phone
        handle_seller_decision_reply(seller: seller, message: body)
        return
      end

      buyer = Buyer.find_by(phone: from_phone)
      if buyer
        pending_confirmation = Order.joins(:order_confirmation)
                                    .where(buyer_id: buyer.id, order_confirmations: { responded_at: nil })
                                    .where(aasm_state: "pending_verification")
                                    .order(created_at: :desc)
                                    .first
        if pending_confirmation
          Orders::ProcessBuyerConfirmationReply.execute(order: pending_confirmation, message: body)
          return
        end
      end

      Orders::CreateOrderFromWhatsappJob.perform_later(
        seller_id: seller.id,
        buyer_phone: from_phone,
        message: body
      )
    rescue StandardError => e
      Rails.logger.error { "WhatsApp process message error: #{e.class}: #{e.message}" }
    end

    def handle_seller_decision_reply(seller:, message:)
      normalized = message.to_s.strip.downcase
      decision = if normalized.start_with?("keep")
        "keep_waiting"
      elsif normalized.start_with?("cancel")
        "cancelled"
      end
      return if decision.blank?

      target = seller.orders
                     .joins(:order_confirmation)
                     .where(order_confirmations: { responded_at: nil })
                     .where.not(order_confirmations: { seller_notified_at: nil })
                     .order(created_at: :desc)
                     .first
      return if target.blank?

      Orders::ProcessSellerConfirmationDecision.execute(order: target, decision: decision)
    end

    def meta_signature_valid?(raw_body)
      return true if Rails.env.test?

      signature_header = request.headers["X-Hub-Signature-256"].to_s
      return false if signature_header.blank?

      app_secret = Rails.application.credentials.meta[:app_secret].to_s
      return false if app_secret.blank?

      expected = "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), app_secret, raw_body)}"
      ActiveSupport::SecurityUtils.secure_compare(expected, signature_header)
    end
  end
end
