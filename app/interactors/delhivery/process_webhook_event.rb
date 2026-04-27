# frozen_string_literal: true

require "ostruct"

module Delhivery
  class ProcessWebhookEvent
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(waybill:, status:, status_datetime:, remarks:, agent_name:, agent_phone:, location: nil)
      new(
        waybill: waybill,
        status: status,
        status_datetime: status_datetime,
        remarks: remarks,
        agent_name: agent_name,
        agent_phone: agent_phone,
        location: location
      ).execute
    end

    def initialize(waybill:, status:, status_datetime:, remarks:, agent_name:, agent_phone:, location: nil)
      @waybill = waybill
      @status = status
      @status_datetime = status_datetime
      @remarks = remarks
      @agent_name = agent_name
      @agent_phone = agent_phone
      @location = location
    end

    def execute
      execute_log_and_return_open_struct do
        raise_string_error("Waybill is required") if waybill.to_s.strip.blank?

        order = Order.find_by(awb_number: waybill.to_s.strip)
        if order.blank?
          Rails.logger.warn { "Webhook received for unknown AWB: #{waybill}" }
          return OpenStruct.new(waybill: waybill, status: normalized_status, processed: false, order_id: nil)
        end

        code = normalized_status
        oid = order.id

        case code
        when "OFD"
          validate_result_without_raising_error(
            Orders::ProcessOutForDelivery.execute(
              order_id: oid,
              agent_name: agent_name,
              agent_phone: agent_phone
            )
          )
        when "DL"
          validate_result_without_raising_error(
            Orders::ProcessDelivery.execute(order_id: oid, delivered_at: status_datetime)
          )
        when "RTO", "RTD"
          validate_result_without_raising_error(
            Orders::ProcessRto.execute(order_id: oid, rto_at: status_datetime)
          )
        when "DLNA"
          validate_result_without_raising_error(
            Orders::ProcessFailedDelivery.execute(order_id: oid, remarks: remarks)
          )
        else
          log_informational_scan(order, code, remarks, location)
        end

        OpenStruct.new(waybill: waybill, status: code, processed: true, order_id: oid)
      end
    end

    private

    attr_reader :waybill, :status, :status_datetime, :remarks, :agent_name, :agent_phone, :location

    def normalized_status
      status.to_s.strip.upcase
    end

    def log_informational_scan(order, code, remarks_text, location_text)
      suffix = code.to_s.downcase.gsub(/[^a-z0-9]+/i, "_").squeeze("_").delete_prefix("_").delete_suffix("_")
      suffix = "unknown" if suffix.blank?
      event_name = "delhivery_#{suffix}"

      state = order.aasm_state.to_s
      order.order_events.create!(
        from_state: state,
        to_state: state,
        event_name: event_name,
        triggered_by: "system",
        metadata: {
          status: code,
          remarks: remarks_text,
          location: location_text
        }.compact.stringify_keys
      )
    end
  end
end
