# frozen_string_literal: true

class OrdersController < ApplicationController
  layout "dashboard"

  before_action :authenticate_seller!
  before_action :set_order, only: [
    :show, :edit, :update, :destroy, :override_risk, :cancel_order,
    :seller_manual_risk, :seller_manual_address, :seller_manual_confirm,
    :seller_manual_advance_link, :seller_manual_advance_received
  ]

  def index
    base_scope = current_seller.orders.includes(:buyer, :buyer_address)
    @total_orders = current_seller.orders.count
    @pending_orders = current_seller.orders.where(aasm_state: :pending_verification).count
    @confirmed_orders = current_seller.orders.where(aasm_state: :confirmed).count
    @rto_rate = calculate_rto_rate

    @query = params[:q].to_s.strip
    @status = params[:status].to_s
    @per_page = params[:per_page].to_i
    @per_page = 25 unless [10, 25, 50, 100].include?(@per_page)
    @sort_by = params[:sort_by].to_s
    @sort_dir = params[:sort_dir].to_s == "asc" ? "asc" : "desc"

    scope = base_scope.joins(:buyer)
    if @query.present?
      scope = scope.where(
        "buyers.name ILIKE :q OR orders.product_name ILIKE :q OR buyers.phone ILIKE :q",
        q: "%#{@query}%"
      )
    end

    if @status.present? && @status != "all"
      scope = scope.where(aasm_state: @status)
    end

    sort_map = {
      "buyer" => "buyers.name",
      "product" => "orders.product_name",
      "amount" => "orders.amount",
      "status" => "orders.aasm_state",
      "created_at" => "orders.created_at"
    }
    sort_col = sort_map[@sort_by] || "orders.created_at"
    scope = scope.order(Arel.sql("#{sort_col} #{@sort_dir}"))

    @pagy, @orders = pagy(scope, items: @per_page)
  end

  def show
    @buyer = @order.buyer
    @active_products = current_seller.products.active.order(:name)
    @order_events = @order.order_events.order(created_at: :desc)
    @latest_order_event = @order_events.first
    @ofd_event = @order.order_events.where(event_name: "out_for_delivery").order(created_at: :desc).first
  end

  def edit
    unless @order.editable_by_seller?
      redirect_to order_path(@order), alert: "This order can no longer be edited."
      return
    end

    @order_form = order_form_from_order(@order)
    @products = current_seller.products.active.order(:name)
  end

  def new
    @order = OrderForm.new
    @products = current_seller.products.active.order(:name)
  end

  def manual
    @order = OrderForm.new
    render :manual
  end

  def parse
    raw = params[:raw_message].to_s
    result = Orders::ParseWhatsappMessage.execute(raw_message: raw, seller: current_seller)
    unless result.success?
      @parse_error = result.errors.to_s
      return render :parse_error, status: :unprocessable_entity
    end

    parsed = result.data
    composed_address = [
      parsed.raw_address,
      parsed.address_line,
      parsed.city,
      parsed.state,
      parsed.pincode
    ].map { |v| v.to_s.strip.presence }.compact.join(", ")

    @autofilled = {
      "buyer_name" => parsed.buyer_name.present?,
      "buyer_phone" => parsed.buyer_phone.present?,
      "product_name" => parsed.product_name.present?,
      "amount" => parsed.amount.present?,
      "raw_address" => composed_address.present?,
      "payment_type" => true
    }

    @order = OrderForm.new(
      buyer_name: parsed.buyer_name,
      buyer_phone: parsed.buyer_phone,
      product_name: parsed.product_name,
      amount: parsed.amount,
      raw_address: composed_address,
      raw_message: raw,
      seller_note: parsed.special_instructions,
      payment_type: parsed.is_cod ? "full_cod" : "full_prepaid"
    )
    @order.product_id = parsed.matched_product_id
    render :parse_success
  end

  def create
    @order = OrderForm.new(order_params)
    @products = current_seller.products.active.order(:name)
    unless @order.valid?
      return render :new, status: :unprocessable_entity
    end

    result = Orders::CreateOrder.execute(
      seller_id: current_seller.id,
      buyer_name: @order.buyer_name,
      buyer_phone: @order.buyer_phone,
      product_name: @order.product_name,
      product_id: order_params[:product_id],
      amount: @order.amount,
      raw_address: @order.raw_address,
      raw_message: @order.raw_message,
      seller_note: @order.seller_note,
      payment_type: @order.payment_type,
      verification_mode: :seller_manual
    )

    if result.success?
      redirect_to order_path(result.data), notice: "Order created successfully.", status: :see_other
    else
      flash.now[:alert] = result.errors.to_s
      render :new, status: :unprocessable_entity
    end
  end

  def update
    json_product_link =
      request.patch? && params[:product_id].present? && params[:order].blank?
    if request.format.json? || json_product_link
      return update_product_link_json
    end

    unless @order.editable_by_seller?
      redirect_to order_path(@order), alert: "This order can no longer be edited."
      return
    end

    @order_form = OrderForm.new(order_params)
    @products = current_seller.products.active.order(:name)
    unless @order_form.valid?
      flash.now[:alert] = @order_form.errors.full_messages.to_sentence
      return render :edit, status: :unprocessable_entity
    end

    result = Orders::UpdateOrder.execute(
      order_id: @order.id,
      seller_id: current_seller.id,
      buyer_name: @order_form.buyer_name,
      buyer_phone: @order_form.buyer_phone,
      product_name: @order_form.product_name,
      product_id: order_params[:product_id],
      amount: @order_form.amount,
      raw_address: @order_form.raw_address,
      raw_message: @order_form.raw_message,
      seller_note: @order_form.seller_note,
      payment_type: @order_form.payment_type
    )

    if result.success?
      redirect_to order_path(@order), notice: "Order updated.", status: :see_other
    else
      flash.now[:alert] = result.errors.to_s
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    result = Orders::DestroyOrder.execute(order_id: @order.id, seller_id: current_seller.id)
    if result.success?
      redirect_to orders_path, notice: "Order deleted."
    else
      redirect_back fallback_location: orders_path, alert: result.errors.to_s
    end
  end

  def override_risk
    if params[:decision].present?
      if @order.order_advance_payment&.seller_notified_at.present? && @order.order_advance_payment&.paid_at.nil?
        result = Orders::ProcessSellerAdvanceDecision.execute(order: @order, decision: params[:decision])
      else
        result = Orders::ProcessSellerConfirmationDecision.execute(order: @order, decision: params[:decision])
      end
      if result.success?
        redirect_to order_path(@order), notice: "Seller decision saved."
      else
        redirect_to order_path(@order), alert: result.errors.to_s
      end
      return
    end

    result = Orders::ConfirmOrder.execute(order_id: @order.id, triggered_by: "seller")
    if result.success?
      redirect_to order_path(@order), notice: "Order approved by seller."
    else
      redirect_to order_path(@order), alert: result.errors.to_s
    end
  end

  def cancel_order
    result = Orders::CancelOrder.execute(order_id: @order.id, reason: "Cancelled by seller", triggered_by: "seller")
    if result.success?
      redirect_to order_path(@order), notice: "Order cancelled."
    else
      redirect_to order_path(@order), alert: result.errors.to_s
    end
  end

  def seller_manual_risk
    redirect_with_manual_step(Orders::SellerManual::RunRiskStep.execute(order_id: @order.id), "Risk score updated for this buyer.")
  end

  def seller_manual_address
    apply_manual_flow_buyer_address_edit_if_present
    redirect_with_manual_step(
      Orders::SellerManual::ValidateAddressStep.execute(order_id: @order.id),
      "Address validated — you can confirm the order when ready."
    )
  end

  def seller_manual_confirm
    redirect_with_manual_step(Orders::SellerManual::ConfirmOrderStep.execute(order_id: @order.id), "Order confirmed.")
  end

  def seller_manual_advance_link
    unless Orders::SellerManualFlow::ENABLE_BUYER_RAZORPAY_PAYMENT_LINKS
      redirect_to order_path(@order), alert: "Razorpay payment link generation is disabled. Collect payment however you prefer, then mark it received on the order."
      return
    end

    notice =
      if @order.full_prepaid?
        "Prepaid Razorpay payment link is ready."
      else
        "COD advance payment link is ready."
      end
    redirect_with_manual_step(Orders::SellerManual::CreateAdvanceLink.execute(order_id: @order.id), notice)
  end

  def seller_manual_advance_received
    notice =
      if @order.full_prepaid?
        "Prepaid payment recorded as received."
      else
        "COD advance recorded as received."
      end
    redirect_with_manual_step(Orders::SellerManual::MarkAdvanceReceived.execute(order_id: @order.id), notice)
  end

  private

  def redirect_with_manual_step(result, notice)
    if result.success?
      redirect_to order_path(@order), notice: notice
    else
      redirect_to order_path(@order), alert: result.errors.to_s
    end
  end

  # When the seller edits the delivery text from the checklist, clear prior validation
  # so Google runs again on the new text (same POST as "Verify").
  def apply_manual_flow_buyer_address_edit_if_present
    raw = params.dig(:buyer_address, :raw_address)&.to_s&.strip
    return if raw.blank?

    addr = @order.buyer_address
    return if addr.blank?
    return if raw == addr.raw_address.to_s.strip

    addr.update!(
      raw_address: raw,
      validated_at: nil,
      address_confidence: "pending",
      address_formatted: nil,
      latitude: nil,
      longitude: nil
    )
  end

  def calculate_rto_rate
    total = current_seller.orders.count
    return 0 if total.zero?

    rto_count = current_seller.orders.where(aasm_state: :rto).count
    ((rto_count.to_f / total) * 100).round(1)
  end

  def set_order
    @order = current_seller.orders.find(params[:id])
  end

  def order_params
    params.require(:order).permit(
      :buyer_name, :buyer_phone, :product_name, :amount, :raw_address,
      :raw_message, :seller_note, :payment_type, :product_id
    )
  end

  def order_form_from_order(order)
    OrderForm.new(
      buyer_name: order.buyer.name,
      buyer_phone: order.buyer.phone,
      product_name: order.product_name,
      product_id: order.product_id,
      amount: order.amount,
      raw_address: order.buyer_address&.raw_address,
      raw_message: order.raw_message,
      seller_note: order.seller_note,
      payment_type: order.payment_type
    )
  end

  def update_product_link_json
    product_id = params[:product_id].presence || params.dig(:order, :product_id)
    if product_id.blank?
      render json: { error: "product_id is required" }, status: :unprocessable_entity
      return
    end

    product = current_seller.products.active.find_by(id: product_id)
    if product.nil?
      render json: { error: "Invalid product selection" }, status: :unprocessable_entity
      return
    end

    @order.update!(product: product)
    render json: { ok: true, product_name: product.name }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
