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

ActiveRecord::Schema[8.1].define(version: 2026_05_06_142828) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "deliveries", force: :cascade do |t|
    t.datetime "batch_begin_at"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "delivery_reference"
    t.string "delivery_schedule", default: "immediate", null: false, comment: "Either 'immediate' if the delivery is for a single submission or a value representing the schedule for sending multiple submissions."
    t.datetime "failed_at"
    t.jsonb "failure_details"
    t.string "failure_reason"
    t.datetime "last_attempt_at"
    t.datetime "updated_at", null: false
    t.index ["delivery_reference"], name: "index_deliveries_on_delivery_reference"
  end

  create_table "submission_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "delivery_id", null: false
    t.bigint "submission_id", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_submission_deliveries_on_delivery_id"
    t.index ["submission_id"], name: "index_submission_deliveries_on_submission_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.jsonb "answers"
    t.datetime "created_at", null: false
    t.jsonb "form_document"
    t.integer "form_id"
    t.string "mode"
    t.string "reference"
    t.string "submission_locale", default: "en", null: false, comment: "The language the form was submitted in ISO 2 letter format. Normally either 'en' or 'cy'"
    t.datetime "updated_at", null: false
    t.index ["created_at", "form_id", "mode"], name: "index_submissions_on_created_at_and_form_id_and_mode"
  end

  add_foreign_key "submission_deliveries", "deliveries"
  add_foreign_key "submission_deliveries", "submissions"
end
