# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Whatsapp
  class SendTextMessage
    include ExecuteMethodHelper
    include LogHelper
    include PhoneHelper

    META_API_VERSION = "v19.0"

    def self.execute(to:, text:)
      new(to: to, text: text).execute
    end

    def initialize(to:, text:)
      @to = to
      @text = text.to_s
    end

    def execute
      execute_log_and_return_open_struct do
        phone = normalize_phone(to)
        raise_string_error("Phone is required") if phone.blank?
        raise_string_error("Message text is required") if text.strip.blank?

        token = Rails.application.credentials.dig(:meta, :whatsapp_token).to_s
        phone_number_id = Rails.application.credentials.dig(:meta, :phone_number_id).to_s
        raise_string_error("WhatsApp credentials missing") if token.blank? || phone_number_id.blank?

        uri = URI.parse("https://graph.facebook.com/#{META_API_VERSION}/#{phone_number_id}/messages")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 10
        http.open_timeout = 5

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(
          messaging_product: "whatsapp",
          to: "91#{phone}",
          type: "text",
          text: { body: text }
        )

        response = http.request(request)
        raise_string_error("WhatsApp API error: [#{response.code}] #{response.body}") unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end

    private

    attr_reader :to, :text
  end
end
