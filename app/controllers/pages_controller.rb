# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    redirect_to dashboard_path if seller_signed_in?
  end
end
