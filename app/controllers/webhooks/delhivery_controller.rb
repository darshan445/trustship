# frozen_string_literal: true

require "json"

module Webhooks
  class DelhiveryController < ActionController::Base
    skip_forgery_protection

    def receive
      token = request.headers["X-Delhivery-Token"].to_s
      expected = Rails.application.credentials.delhivery[:webhook_token].to_s

      if expected.blank? || token.bytesize != expected.bytesize || !ActiveSupport::SecurityUtils.secure_compare(token, expected)
        Rails.logger.warn { "Invalid Delhivery webhook token" }
        head :forbidden
        return
      end

      body = JSON.parse(request.raw_post)
      waybill = body["waybill"]
      status = body["status"] || body["act"]
      status_datetime = body["status_datetime"]
      remarks = body["remarks"]
      agent_name = body["agent_name"]
      agent_phone = body["agent_phone"]
      location = body["location"]

      result = Delhivery::ProcessWebhookEvent.execute(
        waybill: waybill,
        status: status,
        status_datetime: status_datetime,
        remarks: remarks,
        agent_name: agent_name,
        agent_phone: agent_phone,
        location: location
      )

      Rails.logger.info do
        "Delhivery webhook: waybill=#{waybill} status=#{status} success=#{result.success?} " \
          "detail=#{result.success? ? result.data.inspect : result.errors.inspect}"
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error { "Delhivery webhook JSON error: #{e.message}" }
      head :ok
    rescue StandardError => e
      Rails.logger.error { "Delhivery webhook error: #{e.class}: #{e.message}" }
      head :ok
    end
  end
end
