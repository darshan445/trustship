# frozen_string_literal: true

require "ostruct"

module Delhivery
  class ProcessWebhookEvent
    include ExecuteMethodHelper
    include LogHelper

    # Log-only [status_type, status_name] pairs (case-insensitive status_name).
    LOG_ONLY_PAIRS = [
      %w[UD Manifested],
      %w[UD Not Picked],
      %w[UD In Transit],
      %w[UD Pending],
      %w[RT In Transit],
      %w[RT Pending],
      %w[RT Dispatched],
      %w[PP Open],
      %w[PP Scheduled],
      %w[PP Dispatched],
      %w[PU In Transit],
      %w[PU Pending],
      %w[PU Dispatched],
      %w[DL DTO],
      %w[CN Canceled],
      %w[CN Cancelled],
      %w[CN Closed]
    ].freeze

    def self.execute(waybill:, status:, status_name:, status_datetime:, remarks:, agent_name:, agent_phone:, location: nil)
      new(
        waybill: waybill,
        status: status,
        status_name: status_name,
        status_datetime: status_datetime,
        remarks: remarks,
        agent_name: agent_name,
        agent_phone: agent_phone,
        location: location
      ).execute
    end

    def initialize(waybill:, status:, status_name:, status_datetime:, remarks:, agent_name:, agent_phone:, location: nil)
      @waybill = waybill
      @status = status
      @status_name = status_name
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
          return OpenStruct.new(
            waybill: waybill,
            status: normalized_status_type,
            status_name: status_name.to_s,
            processed: false,
            order_id: nil
          )
        end

        type = normalized_status_type
        name = status_name.to_s.strip
        oid = order.id

        Rails.logger.info do
          "Delhivery webhook processing order=#{oid} awb=#{waybill} " \
            "status_type=#{type} status_name=#{name}"
        end

        from_state = order.aasm_state.to_s
        unknown_pair = unknown_pair?(type, name)

        case active_action(type, name)
        when :ofd
          validate_result_without_raising_error(
            Orders::ProcessOutForDelivery.execute(
              order_id: oid,
              agent_name: agent_name,
              agent_phone: agent_phone
            )
          )
        when :delivered
          validate_result_without_raising_error(
            Orders::ProcessDelivery.execute(order_id: oid, delivered_at: status_datetime)
          )
        when :rto
          validate_result_without_raising_error(
            Orders::ProcessRto.execute(order_id: oid, rto_at: status_datetime)
          )
        end

        order.reload
        to_state = order.aasm_state.to_s

        record_delhivery_webhook_event(
          order,
          from_state,
          to_state,
          type,
          name,
          unknown: unknown_pair
        )

        OpenStruct.new(
          waybill: waybill,
          status: type,
          status_name: name,
          processed: true,
          order_id: oid
        )
      end
    end

    private

    attr_reader :waybill, :status, :status_name, :status_datetime, :remarks, :agent_name, :agent_phone, :location

    def normalized_status_type
      status.to_s.strip.upcase
    end

    def active_action(type, name)
      t = type.to_s.strip.upcase
      n = name.to_s.strip
      return :ofd if t == "UD" && n.casecmp("Dispatched").zero?
      return :delivered if t == "DL" && n.casecmp("Delivered").zero?
      return :rto if t == "DL" && n.casecmp("RTO").zero?

      nil
    end

    def log_only_pair?(type, name)
      t = type.to_s.strip.upcase
      n = name.to_s.strip
      LOG_ONLY_PAIRS.any? { |pair_t, pair_n| pair_t == t && n.casecmp(pair_n).zero? }
    end

    def unknown_pair?(type, name)
      active_action(type, name).nil? && !log_only_pair?(type, name)
    end

    def log_event_name_from_status_name(status_name_text)
      base = status_name_text.to_s.strip.downcase.gsub(" ", "_")
      base = "unknown" if base.blank?
      "delhivery_#{base}"
    end

    def record_delhivery_webhook_event(order, from_state, to_state, status_type, status_name_text, unknown:)
      event_name = if unknown || status_name_text.to_s.strip.blank?
        "delhivery_unknown"
      else
        log_event_name_from_status_name(status_name_text)
      end

      order.order_events.create!(
        from_state: from_state,
        to_state: to_state,
        event_name: event_name,
        triggered_by: "system",
        metadata: {
          status_type: status_type,
          status_name: status_name_text,
          location: location,
          datetime: status_datetime,
          instructions: remarks,
          agent_name: agent_name,
          agent_phone: agent_phone
        }.compact.stringify_keys
      )
    end
  end
end
