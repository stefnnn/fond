class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :customer_name, null: false
      t.string :customer_email, null: false
      t.string :status, null: false, default: "pending"
      t.integer :total_cents, null: false, default: 0
      t.datetime :placed_at, null: false
      t.text :notes
      t.timestamps
    end
    add_index :orders, :status

    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.string :product_name, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false
      t.timestamps
    end

    create_table :order_events do |t|
      t.references :order, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :from_status
      t.string :to_status
      t.text :body
      t.string :author, null: false, default: "system"
      t.datetime :created_at, null: false
    end
  end
end
