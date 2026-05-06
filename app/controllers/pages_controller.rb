# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    redirect_to dashboard_path if seller_signed_in?
  end

  def terms; end

  def privacy; end

  def refund; end

  def cookies; end

  def shipping_policy; end
end
