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

ActiveRecord::Schema[8.1].define(version: 2026_07_12_000001) do
  create_table "line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_id", null: false
    t.string "product_name", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_line_items_on_order_id"
  end

  create_table "order_events", force: :cascade do |t|
    t.string "author", default: "system", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.string "kind", null: false
    t.integer "order_id", null: false
    t.string "to_status"
    t.index ["order_id"], name: "index_order_events_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "customer_email", null: false
    t.string "customer_name", null: false
    t.text "notes"
    t.datetime "placed_at", null: false
    t.string "status", default: "pending", null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_orders_on_status"
  end

  add_foreign_key "line_items", "orders"
  add_foreign_key "order_events", "orders"
end
