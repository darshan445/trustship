module ApplicationHelper
  include Pagy::Frontend

  def dashboard_tab_classes(active)
    base = "flex flex-col items-center rounded-lg py-2 text-center transition-colors"
    active ? "#{base} font-semibold text-indigo-600" : "#{base} font-medium text-gray-500 hover:text-gray-800"
  end

  def orders_tab_active?
    controller_name == "orders" && action_name == "index"
  end

  def new_order_tab_active?
    controller_name == "orders" && %w[new create].include?(action_name)
  end

  def account_tab_active?
    controller_name == "account"
  end
end
