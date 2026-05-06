# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_06_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "buyer_addresses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address_confidence"
    t.string "address_formatted"
    t.uuid "buyer_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_primary", default: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.text "raw_address", null: false
    t.datetime "updated_at", null: false
    t.datetime "validated_at"
    t.index ["address_confidence"], name: "index_buyer_addresses_on_address_confidence"
    t.index ["buyer_id", "is_primary"], name: "index_buyer_addresses_on_buyer_id_and_is_primary"
    t.index ["buyer_id"], name: "index_buyer_addresses_on_buyer_id"
  end

  create_table "buyers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone", null: false
    t.string "risk_level", default: "low", null: false
    t.integer "rto_count", default: 0, null: false
    t.integer "successful_delivery_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["phone"], name: "index_buyers_on_phone", unique: true
  end

  create_table "order_advance_payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.uuid "order_id", null: false
    t.datetime "paid_at"
    t.string "razorpay_payment_id"
    t.string "razorpay_payment_link_id"
    t.string "razorpay_payment_link_url"
    t.datetime "reminded_at"
    t.datetime "seller_decided_at"
    t.string "seller_decision", default: "pending", null: false
    t.datetime "seller_notified_at"
    t.datetime "sent_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_advance_payments_on_order_id", unique: true
    t.index ["paid_at"], name: "index_order_advance_payments_on_paid_at"
    t.index ["razorpay_payment_link_id"], name: "index_order_advance_payments_on_razorpay_payment_link_id", unique: true, where: "(razorpay_payment_link_id IS NOT NULL)"
    t.index ["seller_decision"], name: "index_order_advance_payments_on_seller_decision"
  end

  create_table "order_confirmations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "corrected_address"
    t.datetime "created_at", null: false
    t.uuid "order_id", null: false
    t.datetime "reminded_at"
    t.datetime "responded_at"
    t.string "response"
    t.datetime "seller_decided_at"
    t.string "seller_decision", default: "pending", null: false
    t.datetime "seller_notified_at"
    t.datetime "sent_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_confirmations_on_order_id"
    t.index ["response"], name: "index_order_confirmations_on_response"
    t.index ["seller_decision"], name: "index_order_confirmations_on_seller_decision"
    t.index ["sent_at"], name: "index_order_confirmations_on_sent_at"
  end

  create_table "order_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_name", null: false
    t.string "from_state"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "order_id", null: false
    t.string "to_state", null: false
    t.string "triggered_by", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_events_on_order_id"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "aasm_state", default: "pending_verification", null: false
    t.decimal "advance_amount", precision: 10, scale: 2
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.uuid "buyer_address_id"
    t.uuid "buyer_id", null: false
    t.datetime "created_at", null: false
    t.string "payment_type", default: "full_cod", null: false
    t.uuid "product_id"
    t.string "product_name", null: false
    t.text "raw_message"
    t.uuid "seller_id", null: false
    t.text "seller_note"
    t.datetime "updated_at", null: false
    t.index ["aasm_state"], name: "index_orders_on_aasm_state"
    t.index ["buyer_address_id"], name: "index_orders_on_buyer_address_id"
    t.index ["buyer_id"], name: "index_orders_on_buyer_id"
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["seller_id"], name: "index_orders_on_seller_id"
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "cod_minimum_advance", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2
    t.uuid "seller_id", null: false
    t.string "sku"
    t.datetime "updated_at", null: false
    t.index ["seller_id", "is_active"], name: "index_products_on_seller_id_and_is_active"
    t.index ["seller_id", "name"], name: "index_products_on_seller_id_and_name"
    t.index ["seller_id", "sku"], name: "index_products_on_seller_id_and_sku", unique: true, where: "(sku IS NOT NULL)"
    t.index ["seller_id"], name: "index_products_on_seller_id"
  end

  create_table "sellers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "business_name", null: false
    t.datetime "created_at", null: false
    t.boolean "early_access", default: true, null: false
    t.string "encrypted_password", null: false
    t.string "name", null: false
    t.string "phone", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "status", default: "active", null: false
    t.boolean "terms_accepted", default: false, null: false
    t.datetime "terms_accepted_at"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["phone"], name: "index_sellers_on_phone", unique: true
    t.index ["reset_password_token"], name: "index_sellers_on_reset_password_token", unique: true
  end

  create_table "shipping_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "max_weight_grams"
    t.integer "min_weight_grams", default: 0, null: false
    t.string "name", null: false
    t.string "payment_type", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_type", "min_weight_grams", "max_weight_grams"], name: "index_shipping_rates_on_type_and_weight_range", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "buyer_addresses", "buyers"
  add_foreign_key "order_advance_payments", "orders"
  add_foreign_key "order_confirmations", "orders"
  add_foreign_key "order_events", "orders"
  add_foreign_key "orders", "buyer_addresses"
  add_foreign_key "orders", "buyers"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "sellers"
  add_foreign_key "products", "sellers"
end
