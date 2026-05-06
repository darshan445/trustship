# frozen_string_literal: true

class BuyersController < ApplicationController
  layout "dashboard"

  before_action :authenticate_seller!

  def index
    @query = params[:q].to_s.strip
    @risk = params[:risk].to_s
    @per_page = params[:per_page].to_i
    @per_page = 25 unless [10, 25, 50, 100].include?(@per_page)
    @sort_by = params[:sort_by].to_s
    @sort_dir = params[:sort_dir].to_s == "asc" ? "asc" : "desc"

    scope = Buyer.joins(:orders)
                 .where(orders: { seller_id: current_seller.id })
                 .distinct

    if @query.present?
      scope = scope.where("buyers.name ILIKE :q OR buyers.phone ILIKE :q", q: "%#{@query}%")
    end

    scope = scope.where(risk_level: @risk) if @risk.present? && @risk != "all"

    sort_map = {
      "name" => "buyers.name",
      "phone" => "buyers.phone",
      "risk" => "buyers.risk_level",
      "rto_count" => "buyers.rto_count",
      "successful_delivery_count" => "buyers.successful_delivery_count",
      "created_at" => "buyers.created_at"
    }
    sort_col = sort_map[@sort_by] || "buyers.created_at"
    scope = scope.order(Arel.sql("#{sort_col} #{@sort_dir}"))

    @pagy, @buyers = pagy(scope, items: @per_page)
  end
end
