# frozen_string_literal: true

module OrdersHelper
  def order_status_tabs
    STATUS_TABS
  end

  def orders_sort_link(label, key)
    next_dir = (params[:sort_by].to_s == key && params[:sort_dir].to_s == "asc") ? "desc" : "asc"
    arrow = if params[:sort_by].to_s == key
      params[:sort_dir].to_s == "asc" ? "↑" : "↓"
    else
      ""
    end
    link_to "#{label} #{arrow}".strip, orders_path(request.query_parameters.merge(sort_by: key, sort_dir: next_dir, page: nil)), class: "text-xs font-semibold uppercase tracking-wide text-gray-500 hover:text-gray-700"
  end

  def buyers_sort_link(label, key)
    next_dir = (params[:sort_by].to_s == key && params[:sort_dir].to_s == "asc") ? "desc" : "asc"
    arrow = if params[:sort_by].to_s == key
      params[:sort_dir].to_s == "asc" ? "↑" : "↓"
    else
      ""
    end
    link_to "#{label} #{arrow}".strip, buyers_path(request.query_parameters.merge(sort_by: key, sort_dir: next_dir, page: nil)), class: "text-xs font-semibold uppercase tracking-wide text-gray-500 hover:text-gray-700"
  end

  def order_parse_input_classes(autofilled, field_key)
    key = field_key.to_s
    filled = autofilled[key]
    base = "mt-1 block w-full rounded-lg px-3 py-2 text-gray-900 shadow-sm focus:outline-none focus:ring-1 focus:ring-indigo-500"
    if filled
      "#{base} border border-indigo-200 bg-indigo-50 focus:border-indigo-500"
    else
      "#{base} border border-gray-300 bg-white focus:border-indigo-500 placeholder:text-red-300"
    end
  end

  STATUS_TABS = [
    { label: "All", param: nil },
    { label: "Pending", param: "pending" },
    { label: "Confirmed", param: "confirmed" },
    { label: "High Risk", param: "high_risk" },
    { label: "Shipped", param: "shipped" },
    { label: "Delivered", param: "delivered" },
    { label: "RTO", param: "rto" }
  ].freeze

  def status_badge_classes(order_or_state)
    state = order_or_state.is_a?(Order) ? order_or_state.aasm_state : order_or_state.to_s

    case state
    when "pending_verification"
      "bg-yellow-100 text-yellow-800"
    when "undeliverable", "address_mismatch", "rto"
      "bg-red-100 text-red-800"
    when "high_risk"
      "bg-orange-100 text-orange-900"
    when "confirmed"
      "bg-blue-100 text-blue-900"
    when "green_zone", "delivered"
      "bg-green-100 text-green-900"
    when "shipped", "cancelled"
      "bg-gray-100 text-gray-800"
    else
      "bg-gray-100 text-gray-700"
    end
  end

  def orders_status_filter_active?(param)
    (param.nil? && params[:status].blank?) || params[:status].to_s == param.to_s
  end

  def risk_badge_classes(risk_level)
    case risk_level.to_s
    when "high"
      "bg-red-100 text-red-800"
    when "medium"
      "bg-orange-100 text-orange-900"
    else
      "bg-green-100 text-green-900"
    end
  end

  def compact_risk_badge(order)
    return nil unless order.order_events.where(event_name: "gate_2_completed").exists?

    case order.buyer.risk_level.to_s
    when "high"
      { label: "🔴 High", classes: "bg-red-100 text-red-800" }
    when "medium"
      { label: "🟡 Med", classes: "bg-amber-100 text-amber-800" }
    when "low"
      { label: "🟢 Low", classes: "bg-green-100 text-green-800" }
    else
      { label: "🔵 New", classes: "bg-blue-100 text-blue-800" }
    end
  end

  def compact_location_text(order)
    formatted = order.buyer_address&.address_formatted.to_s
    fallback = order.buyer_address&.raw_address.to_s
    source = formatted.present? ? formatted : fallback
    return "Address unverified" if source.blank?

    pincode = source[/\b\d{5,6}\b/]
    parts = source.split(",").map(&:strip).reject(&:blank?)
    city_state =
      if parts.size >= 2
        [parts[-3], parts[-2]].compact.join(", ").presence || parts.last(2).join(", ")
      else
        parts.first
      end
    [city_state.presence || "Address unverified", pincode.presence].compact.join(" · ")
  end

  def order_shipment_cod_to_collect(order)
    return nil if order.full_prepaid?

    if order.partial_cod?
      (order.amount - (order.advance_amount || 0)).round(2)
    else
      order.amount
    end
  end

  def order_payment_type_badge_classes(order)
    case order.payment_type
    when "full_prepaid"
      "bg-green-100 text-green-800"
    when "partial_cod"
      "bg-amber-100 text-amber-900"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def order_event_title(event_name)
    case event_name.to_s
    when "mark_undeliverable" then "Marked Undeliverable"
    when "mark_high_risk" then "Marked High Risk"
    when "confirm" then "Order Confirmed"
    when "mark_address_mismatch" then "Address Mismatch"
    when "enter_green_zone" then "Entered Green Zone"
    when "ship" then "Shipped"
    when "mark_delivered" then "Delivered"
    when "mark_rto" then "Returned (RTO)"
    when "cancel" then "Cancelled"
    when "out_for_delivery" then "Out for Delivery"
    when "delivery_failed" then "Delivery Attempt Failed"
    else
      event_name.to_s.tr("_", " ").titleize
    end
  end

  def order_event_detail_lines(event)
    meta = event.metadata || {}
    case event.event_name.to_s
    when "out_for_delivery"
      lines = []
      name = meta["agent_name"].presence
      phone = meta["agent_phone"].presence
      lines << "Agent: #{name}" if name
      lines << "Phone: #{phone}" if phone
      lines
    when "delivery_failed"
      r = meta["remarks"].presence
      r ? [ "Remarks: #{r}" ] : []
    when "mark_undeliverable"
      r = meta["reason"].presence
      r ? [ "Reason: #{r}" ] : []
    else
      []
    end
  end

  def live_tracking_status_badge_classes(order)
    case order.aasm_state.to_s
    when "delivered"
      "bg-green-600 text-white"
    when "rto"
      "bg-red-600 text-white"
    when "shipped"
      "bg-indigo-600 text-white"
    else
      "bg-gray-600 text-white"
    end
  end
end
