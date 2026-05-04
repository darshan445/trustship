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

ActiveRecord::Schema[8.1].define(version: 2026_05_04_120000) do
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
    t.string "address_line", null: false
    t.decimal "advance_amount", precision: 10, scale: 2
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "awb_number"
    t.datetime "buyer_confirmed_at"
    t.uuid "buyer_id", null: false
    t.datetime "buyer_risk_assessed_at"
    t.string "city", null: false
    t.datetime "confirmation_reminder_sent_at"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.string "delhivery_shipment_id"
    t.datetime "delivered_at"
    t.datetime "payment_link_expires_at"
    t.string "payment_type", default: "full_cod", null: false
    t.string "pincode", null: false
    t.datetime "pincode_verified_at"
    t.datetime "prepaid_incentive_sent_at"
    t.string "product_name", null: false
    t.text "raw_message"
    t.string "razorpay_payment_id"
    t.string "razorpay_payment_link_id"
    t.string "razorpay_payment_link_url"
    t.datetime "rto_at"
    t.uuid "seller_id", null: false
    t.text "seller_note"
    t.datetime "shipped_at"
    t.string "state", null: false
    t.datetime "undeliverable_at"
    t.datetime "updated_at", null: false
    t.index ["aasm_state"], name: "index_orders_on_aasm_state"
    t.index ["awb_number"], name: "index_orders_on_awb_number", unique: true
    t.index ["buyer_id"], name: "index_orders_on_buyer_id"
    t.index ["razorpay_payment_link_id"], name: "index_orders_on_razorpay_payment_link_id", unique: true, where: "(razorpay_payment_link_id IS NOT NULL)"
    t.index ["seller_id"], name: "index_orders_on_seller_id"
  end

  create_table "sellers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "business_name", null: false
    t.datetime "created_at", null: false
    t.string "delhivery_pickup_location_name"
    t.string "encrypted_password", null: false
    t.string "name", null: false
    t.string "phone", null: false
    t.string "pickup_address_line"
    t.string "pickup_city"
    t.string "pickup_name"
    t.string "pickup_phone"
    t.string "pickup_pincode"
    t.string "pickup_state"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "shop_code", null: false
    t.string "status", default: "active", null: false
    t.boolean "terms_accepted", default: false, null: false
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.index ["phone"], name: "index_sellers_on_phone", unique: true
    t.index ["reset_password_token"], name: "index_sellers_on_reset_password_token", unique: true
    t.index ["shop_code"], name: "index_sellers_on_shop_code", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "order_events", "orders"
  add_foreign_key "orders", "buyers"
  add_foreign_key "orders", "sellers"
end
