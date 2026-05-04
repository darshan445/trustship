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
      shipment   = body["Shipment"] || {}
      status_obj = shipment["Status"] || {}

      waybill          = shipment["AWB"].to_s
      status           = status_obj["StatusType"].to_s
      status_name      = status_obj["Status"].to_s
      status_datetime  = status_obj["StatusDateTime"].to_s
      remarks          = status_obj["Instructions"].to_s
      location         = status_obj["StatusLocation"].to_s
      agent_name       = shipment["AgentName"].to_s
      agent_phone      = shipment["AgentPhone"].to_s

      result = Delhivery::ProcessWebhookEvent.execute(
        waybill: waybill,
        status: status,
        status_name: status_name,
        status_datetime: status_datetime,
        remarks: remarks,
        location: location,
        agent_name: agent_name,
        agent_phone: agent_phone
      )

      Rails.logger.info do
        "Delhivery webhook: waybill=#{waybill} status_type=#{status} status_name=#{status_name} " \
          "success=#{result.success?} " \
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
