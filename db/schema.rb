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

ActiveRecord::Schema[8.1].define(version: 2026_01_12_190123) do
  create_table "addresses", force: :cascade do |t|
    t.string "building_number", limit: 250
    t.string "city", limit: 250
    t.string "country_code", limit: 5
    t.datetime "created_at", null: false
    t.float "latitude"
    t.float "longitude"
    t.string "name", limit: 250, null: false
    t.string "postal_code", limit: 100
    t.string "state_code", limit: 50
    t.string "street_name", limit: 250
    t.datetime "updated_at", null: false
  end

  create_table "attendees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.integer "member_id", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_attendees_on_event_id"
    t.index ["member_id", "event_id"], name: "index_attendees_on_member_id_and_event_id", unique: true
    t.index ["member_id"], name: "index_attendees_on_member_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "address_id"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description", limit: 100000
    t.datetime "end", null: false
    t.integer "event_type", null: false
    t.integer "group_id", null: false
    t.bigint "manager_id"
    t.string "name", limit: 250, null: false
    t.datetime "start", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_events_on_group_id"
  end

  create_table "groups", force: :cascade do |t|
    t.integer "address_id"
    t.datetime "created_at", null: false
    t.text "description", limit: 100000
    t.integer "group_type", null: false
    t.string "name", limit: 250, null: false
    t.datetime "updated_at", null: false
  end

  create_table "members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_id", null: false
    t.integer "role", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["group_id"], name: "index_members_on_group_id"
    t.index ["user_id", "group_id"], name: "index_members_on_user_id_and_group_id", unique: true
    t.index ["user_id"], name: "index_members_on_user_id"
  end

  create_table "user_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "first_name", limit: 250
    t.string "last_name", limit: 250
    t.string "mobile_phone", limit: 50
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["mobile_phone"], name: "index_user_profiles_on_mobile_phone", unique: true
    t.index ["user_id"], name: "index_user_profiles_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", limit: 250, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "attendees", "events", on_update: :cascade, on_delete: :cascade
  add_foreign_key "attendees", "members", on_update: :cascade, on_delete: :cascade
  add_foreign_key "events", "addresses", on_update: :cascade, on_delete: :restrict
  add_foreign_key "events", "groups", on_update: :cascade, on_delete: :cascade
  add_foreign_key "groups", "addresses", on_update: :cascade, on_delete: :restrict
  add_foreign_key "members", "groups", on_update: :cascade, on_delete: :cascade
  add_foreign_key "members", "users", on_update: :cascade, on_delete: :cascade
  add_foreign_key "user_profiles", "users", on_update: :cascade, on_delete: :cascade
end
