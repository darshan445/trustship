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

    def self.execute(raw_message:, seller: nil)
      new(raw_message: raw_message, seller: seller).execute
    end

    def initialize(raw_message:, seller: nil)
      @raw_message = raw_message
      @seller = seller
    end

    def execute
      execute_log_and_return_open_struct do
        validate_raw_message!
        products = fetch_seller_products
        prompt = build_prompt(@raw_message, products)
        response_body = call_gemini_api(prompt)
        text = extract_text_from_response(response_body)
        order_hash = parse_order_json(text)
        build_result_open_struct(order_hash, products)
      end
    end

    private

    attr_reader :raw_message, :seller

    def validate_raw_message!
      raise_string_error("Message cannot be blank") if raw_message.to_s.strip.blank?
    end

    def fetch_seller_products
      return [] if seller.nil?

      seller.products
            .active
            .select(:id, :name, :price)
            .order(:name)
            .map do |p|
              {
                id: p.id,
                name: p.name,
                price: p.price&.to_f
              }
            end
    rescue StandardError => e
      Rails.logger.error("Failed to fetch seller products for parsing: #{e.message}")
      []
    end

    def build_prompt(message, products = [])
      product_section = if products.any?
        product_list = products.map.with_index(1) do |p, i|
          price_hint = p[:price] ? " (₹#{p[:price].to_i})" : ""
          "#{i}. #{p[:name]}#{price_hint} [id: #{p[:id]}]"
        end.join("\n")

        <<~PRODUCTS

          Seller's product catalog:
          #{product_list}

          Try to match the ordered item to one of the products above.
          - If confident match: return the product's id in "matched_product_id"
          - If unsure or no match: return null for "matched_product_id"
          - Never force a match if uncertain
        PRODUCTS
      else
        "\n(No product catalog available - skip product matching)\n"
      end

      <<~PROMPT
        You are an order parser for a WhatsApp selling platform.

        Extract order details from casual, informal WhatsApp messages. Messages may be in any language, broken, incomplete, or missing details — extract whatever is available.

        Return ONLY a valid JSON object. No explanation. No markdown. No code blocks. Just raw JSON.

        Fields:
        - buyer_name: string or null
        - buyer_phone: string or null (if mentioned: 10 digits for Indian numbers, digits only)
        - product: string or null
        - quantity: integer or null
        - amount: decimal number or null (no currency symbol)
        - payment_type: one of "cod", "prepaid", "unknown", or null
        - address: string or null (full or partial delivery address)
        - city: string or null
        - state: string or null
        - pincode: string or null (6 digits if Indian pincode)
        - special_instructions: string or null
        - matched_product_id: string or null (UUID from product catalog if confident match found, else null)
        - match_confidence: one of "high", "medium", "low", or null (how confident the product match is: high = clear name/price match, medium = likely, low = vague guess, null = no match)

        Also include for backward compatibility when clearly known:
        - address_line, product_name, is_cod — use null if redundant with the fields above

        Rules:
        - Return null for any field not mentioned or unclear
        - Never guess or assume missing fields
        - For amount: number only, no ₹ or currency text
        - For matched_product_id: only return a value if genuinely confident. When in doubt, return null.
        #{product_section}

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

    def build_result_open_struct(order_hash, products = [])
      h = order_hash.stringify_keys
      amount_value = cast_amount(h["amount"])

      product_label = build_product_label(h)
      address_line = h["address"].presence || h["address_line"].presence
      pincode_value = normalize_pincode_field(h["pincode"])
      is_cod_value = derive_is_cod(h)
      matched_product_id = resolve_product_match(
        h["matched_product_id"],
        h["match_confidence"],
        products
      )

      ::OpenStruct.new(
        buyer_name: h["buyer_name"],
        buyer_phone: h["buyer_phone"],
        product_name: product_label,
        amount: amount_value,
        raw_address: address_line,
        address_line: address_line,
        city: h["city"],
        state: h["state"],
        pincode: pincode_value,
        is_cod: is_cod_value,
        special_instructions: h["special_instructions"],
        raw_message: raw_message,
        parsed_successfully: true,
        matched_product_id: matched_product_id,
        match_confidence: h["match_confidence"]
      )
    end

    def resolve_product_match(gemini_product_id, confidence, products)
      return nil if gemini_product_id.blank?
      return nil if products.empty?
      return nil if confidence.to_s == "low"

      valid_ids = products.map { |p| p[:id].to_s }
      return nil unless valid_ids.include?(gemini_product_id.to_s)

      gemini_product_id.to_s
    rescue StandardError => e
      Rails.logger.error("Product match resolution failed: #{e.message}")
      nil
    end

    def build_product_label(h)
      base = h["product"].presence || h["product_name"].presence
      qty = h["quantity"]
      return nil if base.blank?

      if qty.nil?
        base.to_s.strip
      else
        "#{base.to_s.strip} × #{qty}"
      end
    end

    def normalize_pincode_field(value)
      s = value.to_s.strip
      return nil if s.blank?
      return s if s.match?(/\A\d{6}\z/)

      nil
    end

    def derive_is_cod(h)
      pt = h["payment_type"].to_s.downcase.strip
      case pt
      when "prepaid"
        false
      when "cod"
        true
      when "unknown", ""
        if h.key?("is_cod") && !h["is_cod"].nil?
          ActiveModel::Type::Boolean.new.cast(h["is_cod"])
        else
          true
        end
      else
        if h.key?("is_cod") && !h["is_cod"].nil?
          ActiveModel::Type::Boolean.new.cast(h["is_cod"])
        else
          true
        end
      end
    end

    def cast_amount(value)
      return nil if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
