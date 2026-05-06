# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
#
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

if ActiveRecord::Base.connection.table_exists?(:shipping_rates)
  SEED_SHIPPING_RATES = [
    [ "COD 0-500g", "cod", 0, 500, 87 ],
    [ "COD 501g-1kg", "cod", 501, 1000, 120 ],
    [ "COD 1kg-2kg", "cod", 1001, 2000, 155 ],
    [ "COD 2kg-5kg", "cod", 2001, 5000, 210 ],
    [ "Prepaid 0-500g", "prepaid", 0, 500, 47 ],
    [ "Prepaid 501g-1kg", "prepaid", 501, 1000, 80 ],
    [ "Prepaid 1kg-2kg", "prepaid", 1001, 2000, 115 ],
    [ "Prepaid 2kg-5kg", "prepaid", 2001, 5000, 170 ]
  ].freeze

  SEED_SHIPPING_RATES.each do |name, payment_type, min_w, max_w, amount|
    r = ShippingRate.find_or_initialize_by(
      payment_type: payment_type,
      min_weight_grams: min_w,
      max_weight_grams: max_w
    )
    r.assign_attributes(name: name, amount: amount, is_active: true)
    r.save!
  end
end
