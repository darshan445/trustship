# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Whatsapp
  class SendMessage
    include ExecuteMethodHelper
    include LogHelper
    include PhoneHelper

    META_API_VERSION = "v19.0"
    READ_TIMEOUT = 10
    OPEN_TIMEOUT = 5

    def self.execute(phone:, template_name:, parameters:)
      new(phone: phone, template_name: template_name, parameters: parameters).execute
    end

    def initialize(phone:, template_name:, parameters:)
      @phone = phone
      @template_name = template_name
      @parameters = parameters
    end

    def execute
      execute_log_and_return_open_struct do
        validate_inputs!
        formatted = format_phone(@normalized_phone)
        body = build_request_body(formatted, template_name, parameters)
        parsed = call_meta_api(body)
        message_id = parsed.dig("messages", 0, "id")
        raise_string_error("WhatsApp API error: missing message id in response") if message_id.blank?

        Rails.logger.info { "WhatsApp message sent to #{@normalized_phone} via template #{template_name}" } if Rails.env.development?

        OpenStruct.new(
          message_id: message_id,
          phone: @normalized_phone,
          template_name: template_name,
          sent_at: Time.current
        )
      end
    end

    private

    attr_reader :phone, :template_name, :parameters

    def validate_inputs!
      @normalized_phone = normalize_phone(phone)
      raise_string_error("Phone is required") if @normalized_phone.blank?
      raise_string_error("Phone must be a valid 10-digit Indian mobile") unless @normalized_phone.match?(Buyer::PHONE_REGEX)

      raise_string_error("Template name is required") if template_name.to_s.strip.blank?

      raise_string_error("Parameters must be an array") unless parameters.is_a?(Array)
    end

    def build_request_body(formatted_phone, tmpl_name, params)
      {
        messaging_product: "whatsapp",
        to: formatted_phone,
        type: "template",
        template: {
          name: tmpl_name,
          language: { code: "en" },
          components: [
            {
              type: "body",
              parameters: params.map { |text| { type: "text", text: text.to_s } }
            }
          ]
        }
      }
    end

    def format_phone(ten_digit)
      "91#{ten_digit}"
    end

    def call_meta_api(body_hash)
      token = Rails.application.credentials.meta[:whatsapp_token]
      phone_number_id = Rails.application.credentials.meta[:phone_number_id]
      raise_string_error("WhatsApp credentials missing") if token.blank? || phone_number_id.blank?

      uri = URI.parse("https://graph.facebook.com/#{META_API_VERSION}/#{phone_number_id}/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = READ_TIMEOUT
      http.open_timeout = OPEN_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body_hash)

      response = http.request(request)
      unless [ Net::HTTP::OK, Net::HTTP::Created ].include?(response.code.to_i)
        raise_string_error("WhatsApp API error: [#{response.code}] #{response.body}")
      end

      JSON.parse(response.body)
    end
  end
end
