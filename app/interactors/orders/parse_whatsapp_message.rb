# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "bigdecimal"
require "ostruct"

module Orders
  class ParseWhatsappMessage
    include ExecuteMethodHelper
    include LogHelper

    GEMINI_HOST = "generativelanguage.googleapis.com"
    # See https://ai.google.dev/gemini-api/docs/models — unversioned 1.5 Flash IDs were retired from v1beta.
    GEMINI_MODEL = "gemini-2.5-flash"
    GEMINI_PATH = "/v1beta/models/#{GEMINI_MODEL}:generateContent"

    def self.execute(raw_message:)
      new(raw_message: raw_message).execute
    end

    def initialize(raw_message:)
      @raw_message = raw_message
    end

    def execute
      execute_log_and_return_open_struct do
        validate_raw_message!
        prompt = build_prompt(@raw_message)
        response_body = call_gemini_api(prompt)
        text = extract_text_from_response(response_body)
        order_hash = parse_order_json(text)
        build_result_open_struct(order_hash)
      end
    end

    private

    attr_reader :raw_message

    def validate_raw_message!
      raise_string_error("Message cannot be blank") if raw_message.to_s.strip.blank?
    end

    def build_prompt(message)
      <<~PROMPT
        You are an order parsing assistant for Indian WhatsApp sellers.

        Extract the following fields from the WhatsApp message below and return ONLY a valid JSON object. No explanation. No markdown. No code blocks. Just raw JSON.

        Fields to extract:
        - buyer_name: full name of the buyer (string or null)
        - buyer_phone: 10-digit Indian mobile number (string or null, digits only, no spaces or dashes)
        - product_name: name of the product ordered (string or null)
        - amount: order amount as a number only, no currency symbol (number or null)
        - address_line: street address or locality (string or null)
        - city: city name (string or null)
        - state: Indian state name in English (string or null)
        - pincode: 6-digit Indian pincode (string or null)
        - is_cod: true if payment is COD or cash on delivery, false if prepaid or paid (boolean, default true if unclear)

        Rules:
        - If a field is not present or unclear, return null for that field
        - For buyer_phone: extract only the 10-digit number, remove +91 or 0 prefix if present
        - For amount: return only the number, no ₹ or Rs symbol
        - For state: always return the full English state name (e.g. "Gujarat" not "GJ")
        - For pincode: must be exactly 6 digits, return null if unclear
        - Do not guess or infer fields that are not clearly present in the message
        - The message may be in Hindi, Hinglish, or English — handle all three

        WhatsApp message:
        #{message}

        Return only the JSON object.
      PROMPT
    end

    def call_gemini_api(prompt)
      gemini_creds = Rails.application.credentials.gemini
      raise_string_error("Gemini API key not configured") if gemini_creds.blank? || gemini_creds[:api_key].blank?

      api_key = gemini_creds[:api_key]

      uri = URI::HTTPS.build(host: GEMINI_HOST, path: GEMINI_PATH, query: URI.encode_www_form({ key: api_key }))

      body = {
        "contents" => [
          {
            "parts" => [
              { "text" => prompt }
            ]
          }
        ],
        "generationConfig" => {
          "temperature" => 0.1,
          # 512 is too small for gemini-2.5-flash: internal "thinking" + JSON often hits MAX_TOKENS and returns truncated invalid JSON.
          "maxOutputTokens" => 2048,
          "responseMimeType" => "application/json"
        }
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 15
      http.open_timeout = 5

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)

      response = http.request(request)

      Rails.logger.debug { "Gemini raw response: #{response.body}" } if Rails.env.development?

      unless response.is_a?(Net::HTTPSuccess)
        raise_string_error("Gemini API error: #{response.code}")
      end

      JSON.parse(response.body)
    rescue Net::ReadTimeout
      raise_string_error("Gemini request timed out")
    rescue Net::OpenTimeout
      raise_string_error("Gemini connection timed out")
    rescue JSON::ParserError
      raise_string_error("Gemini API error: invalid response body")
    end

    def extract_text_from_response(response_body)
      candidates = response_body["candidates"]
      raise_string_error("Gemini returned empty response") if candidates.blank?

      first = candidates[0]
      raise_string_error("Gemini returned empty response") if first.blank?

      if first["finishReason"].to_s == "MAX_TOKENS"
        raise_string_error("Gemini output was truncated (token limit). Increase maxOutputTokens or retry.")
      end

      text = first.dig("content", "parts", 0, "text")
      raise_string_error("Could not read Gemini response") if text.nil?

      text = text.to_s
      raise_string_error("Could not read Gemini response") if text.strip.empty?

      text
    end

    def parse_order_json(text)
      stripped = text.to_s.strip
      stripped = stripped.sub(/\A```(?:json)?\s*\R?/m, "").sub(/\R?```\s*\z/m, "").strip
      parsed = JSON.parse(stripped)
      raise_string_error("Gemini returned invalid JSON") unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError
      raise_string_error("Gemini returned invalid JSON")
    end

    def build_result_open_struct(order_hash)
      h = order_hash.stringify_keys
      amount_value = cast_amount(h["amount"])
      is_cod_value = h.key?("is_cod") && !h["is_cod"].nil? ? ActiveModel::Type::Boolean.new.cast(h["is_cod"]) : true

      ::OpenStruct.new(
        buyer_name: h["buyer_name"],
        buyer_phone: h["buyer_phone"],
        product_name: h["product_name"],
        amount: amount_value,
        address_line: h["address_line"],
        city: h["city"],
        state: h["state"],
        pincode: h["pincode"],
        is_cod: is_cod_value,
        raw_message: raw_message,
        parsed_successfully: true
      )
    end

    def cast_amount(value)
      return nil if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
