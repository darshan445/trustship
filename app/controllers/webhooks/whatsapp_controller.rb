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
      messages = payload.dig("entry", 0, "changes", 0, "value", "messages")
      if messages.blank?
        head :ok
        return
      end

      Array(messages).each do |msg|
        process_incoming_message(msg)
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

    def process_incoming_message(msg)
      return unless msg.is_a?(Hash)
      return unless msg["type"].to_s == "text"

      from_raw = msg["from"].to_s
      body = msg.dig("text", "body")
      return if body.blank?

      from = normalize_phone(from_raw)
      if from.blank?
        Rails.logger.warn { "WhatsApp webhook: could not normalize sender phone #{from_raw.inspect}" }
        return
      end

      first_word = body.strip.split(" ").first&.upcase
      seller = Seller.find_by(shop_code: first_word) if first_word.present?

      if seller.present?
        Orders::CreateOrderFromWhatsappJob.perform_later(phone: from, message: body)
        return
      end

      result = Orders::ProcessBuyerReply.execute(phone: from, reply: body)
      if result.success?
        Rails.logger.info { "ProcessBuyerReply ok for #{from}" }
      else
        Rails.logger.info { "ProcessBuyerReply failed for #{from}: #{result.errors}" }
      end
    rescue StandardError => e
      Rails.logger.error { "WhatsApp process message error: #{e.class}: #{e.message}" }
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
