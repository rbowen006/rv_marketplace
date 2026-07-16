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

ActiveRecord::Schema[8.0].define(version: 2026_07_14_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_requests", force: :cascade do |t|
    t.string "feature", null: false
    t.string "model", null: false
    t.string "prompt_version"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "latency_ms"
    t.decimal "estimated_cost_usd", precision: 10, scale: 6
    t.boolean "success", default: false, null: false
    t.string "error_message"
    t.text "request_payload"
    t.text "response_payload"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "conversation_id"
    t.index ["conversation_id"], name: "index_ai_requests_on_conversation_id"
    t.index ["user_id"], name: "index_ai_requests_on_user_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.string "status", default: "pending", null: false
    t.integer "hirer_id", null: false
    t.integer "rv_listing_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hirer_id"], name: "index_bookings_on_hirer_id"
    t.index ["rv_listing_id"], name: "index_bookings_on_rv_listing_id"
  end

  create_table "chats", force: :cascade do |t|
    t.integer "hirer_id", null: false
    t.integer "owner_id", null: false
    t.integer "rv_listing_id"
    t.integer "booking_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_message_at"
    t.text "last_message_content"
    t.datetime "hirer_last_read_at"
    t.datetime "owner_last_read_at"
    t.index ["booking_id"], name: "index_chats_on_booking_id"
    t.index ["hirer_id", "last_message_at"], name: "index_chats_on_hirer_id_and_last_message_at"
    t.index ["hirer_id"], name: "index_chats_on_hirer_id"
    t.index ["owner_id", "last_message_at"], name: "index_chats_on_owner_id_and_last_message_at"
    t.index ["owner_id"], name: "index_chats_on_owner_id"
    t.index ["rv_listing_id"], name: "index_chats_on_rv_listing_id"
  end

  create_table "concierge_conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "idle", null: false
    t.jsonb "transcript", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "error"
    t.string "step_status"
    t.index ["user_id"], name: "index_concierge_conversations_on_user_id", unique: true
  end

  create_table "knowledge_chunks", force: :cascade do |t|
    t.string "region", null: false
    t.string "heading"
    t.text "content", null: false
    t.vector "embedding", limit: 768
    t.string "model"
    t.string "content_hash", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["region", "content_hash"], name: "index_knowledge_chunks_on_region_and_content_hash", unique: true
    t.index ["region"], name: "index_knowledge_chunks_on_region"
  end

  create_table "listing_embeddings", force: :cascade do |t|
    t.bigint "rv_listing_id", null: false
    t.vector "embedding", limit: 768
    t.text "document"
    t.string "model"
    t.string "content_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rv_listing_id"], name: "index_listing_embeddings_on_rv_listing_id", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "chat_id", null: false
    t.datetime "read_at"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "rv_listings", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.decimal "price_per_day"
    t.integer "owner_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_guests", default: 1, null: false
    t.boolean "pet_friendly", default: false, null: false
    t.float "latitude"
    t.float "longitude"
    t.integer "rv_type", default: 0, null: false
    t.string "town"
    t.string "state"
    t.string "postcode"
    t.string "region"
    t.index ["owner_id"], name: "index_rv_listings_on_owner_id"
  end

  create_table "trip_plans", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.string "status", default: "pending", null: false
    t.text "interests"
    t.jsonb "itinerary"
    t.text "error"
    t.string "input_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_trip_plans_on_booking_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_requests", "concierge_conversations", column: "conversation_id"
  add_foreign_key "ai_requests", "users"
  add_foreign_key "bookings", "rv_listings"
  add_foreign_key "bookings", "users", column: "hirer_id"
  add_foreign_key "chats", "bookings"
  add_foreign_key "chats", "rv_listings"
  add_foreign_key "chats", "users", column: "hirer_id"
  add_foreign_key "chats", "users", column: "owner_id"
  add_foreign_key "concierge_conversations", "users"
  add_foreign_key "listing_embeddings", "rv_listings"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "users"
  add_foreign_key "rv_listings", "users", column: "owner_id"
  add_foreign_key "trip_plans", "bookings"
end
