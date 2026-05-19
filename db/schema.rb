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

ActiveRecord::Schema[8.1].define(version: 2026_05_19_164724) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "service_bullets", force: :cascade do |t|
    t.string "body", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.bigint "service_section_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_section_id", "position"], name: "index_service_bullets_on_service_section_id_and_position"
  end

  create_table "service_sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "heading", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_service_sections_on_slug", unique: true
  end

  create_table "site_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["key"], name: "index_site_settings_on_key", unique: true
  end

  add_foreign_key "service_bullets", "service_sections"
end
