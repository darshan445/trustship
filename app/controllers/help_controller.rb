# frozen_string_literal: true

class HelpController < ApplicationController
  layout "dashboard"

  before_action :authenticate_seller!

  def show; end
end
