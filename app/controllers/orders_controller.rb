# frozen_string_literal: true

class OrdersController < ApplicationController
  layout "dashboard"

  before_action :authenticate_seller!
  before_action :set_order, only: [ :show, :override_risk, :cancel_order, :ship, :fetch_label ]

  def index
    scope = current_seller.orders.includes(:buyer).order(created_at: :desc)
    if params[:status].present? && Order::STATUS_FILTER_MAP.key?(params[:status].to_s)
      scope = scope.where(aasm_state: Order::STATUS_FILTER_MAP[params[:status].to_s])
    end
    @pagy, @orders = pagy(scope)
  end

  def new
    @order = OrderForm.new
  end

  def parse
    raw_message = params[:raw_message].to_s
    if raw_message.strip.blank?
      @parse_error = "Message cannot be blank"
      return render :parse_error, layout: false, status: :unprocessable_entity
    end

    result = Orders::ParseWhatsappMessage.execute(raw_message: raw_message)
    if result.success?
      @parsed = result.data
      @raw_message = raw_message
      @order = order_form_from_parsed(@parsed, @raw_message)
      @autofilled = autofilled_field_map(@parsed)
      render :parse_success, layout: false
    else
      @parse_error = result.errors.to_s
      render :parse_error, layout: false, status: :unprocessable_entity
    end
  end

  def manual
    @order = OrderForm.new
    render :manual, layout: false
  end

  def create
    @order = OrderForm.new(order_params)
    unless @order.valid?
      flash.now[:alert] = "Please fix the errors below."
      return render :new, status: :unprocessable_entity
    end

    result = Orders::CreateOrder.execute(
      seller_id: current_seller.id,
      buyer_name: @order.buyer_name,
      buyer_phone: @order.buyer_phone,
      product_name: @order.product_name,
      amount: @order.amount,
      address_line: @order.address_line,
      city: @order.city,
      state: @order.state,
      pincode: @order.pincode,
      raw_message: @order.raw_message.presence,
      seller_note: @order.seller_note.presence,
      payment_type: @order.payment_type,
      weight_grams: @order.weight_grams
    )

    if result.success?
      redirect_to order_path(result.data), notice: "Order created successfully"
    else
      flash.now[:alert] = result.errors.to_s
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @order_events = @order.order_events.order(created_at: :asc)
    @latest_order_event = @order.order_events.order(created_at: :desc).first
    @ofd_event =
      if @order.shipped?
        @order.order_events.where(event_name: "out_for_delivery").order(created_at: :desc).first
      end
    @buyer = @order.buyer
  end

  def override_risk
    result = Orders::ConfirmOrder.execute(order_id: @order.id, triggered_by: "seller")
    if result.success?
      redirect_to order_path(@order), notice: "Order approved despite risk flag"
    else
      redirect_back fallback_location: order_path(@order), alert: result.errors.to_s
    end
  end

  def cancel_order
    result = Orders::CancelOrder.execute(order_id: @order.id, triggered_by: "seller")
    if result.success?
      redirect_to orders_path, notice: "Order cancelled"
    else
      redirect_back fallback_location: order_path(@order), alert: result.errors.to_s
    end
  end

  def ship
    result = Orders::ShipOrder.execute(order_id: @order.id, seller_id: current_seller.id)

    if result.success?
      redirect_to order_path(@order), notice: "Order shipped! AWB: #{result.data.awb_number}"
    elsif result.errors.to_s.match?(/pickup address/i)
      redirect_to edit_account_path, alert: result.errors.to_s
    else
      redirect_to order_path(@order), alert: result.errors.to_s
    end
  end

  def fetch_label
    if @order.awb_number.blank?
      redirect_to order_path(@order), alert: "AWB number not set on order"
      return
    end

    result = Delhivery::FetchShippingLabel.execute(order_id: @order.id)

    if result.success?
      redirect_to order_path(@order), notice: "Label downloaded successfully"
    else
      redirect_to order_path(@order), alert: result.errors.to_s
    end
  end

  private

  def set_order
    @order = current_seller.orders.with_attached_shipping_label.includes(:buyer, :order_events).find(params[:id])
  end

  def order_params
    params.require(:order).permit(
      :buyer_name, :buyer_phone, :product_name, :amount,
      :address_line, :city, :state, :pincode, :raw_message, :seller_note, :payment_type,
      :weight_grams
    )
  end

  def order_form_from_parsed(parsed, raw_message)
    OrderForm.new(
      buyer_name: parsed.buyer_name,
      buyer_phone: parsed.buyer_phone,
      product_name: parsed.product_name,
      amount: parsed.amount,
      address_line: parsed.address_line,
      city: parsed.city,
      state: parsed.state,
      pincode: parsed.pincode,
      raw_message: raw_message,
      seller_note: nil,
      payment_type: parsed.is_cod ? "full_cod" : "full_prepaid",
      weight_grams: 500
    )
  end

  def autofilled_field_map(parsed)
    {
      "buyer_name" => parsed.buyer_name.present?,
      "buyer_phone" => parsed.buyer_phone.present?,
      "product_name" => parsed.product_name.present?,
      "amount" => !parsed.amount.nil?,
      "address_line" => parsed.address_line.present?,
      "city" => parsed.city.present?,
      "state" => parsed.state.present?,
      "pincode" => parsed.pincode.present?,
      "payment_type" => true,
      "weight_grams" => false
    }
  end
end
