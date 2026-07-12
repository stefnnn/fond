OrderEvent.delete_all
LineItem.delete_all
Order.delete_all

products = [
  ["Aeropress", 4200], ["Chemex 6-cup", 4900], ["Hario V60", 2800],
  ["Fellow Stagg kettle", 16500], ["Baratza Encore", 19900], ["Filter papers x100", 900],
  ["Ethiopia Yirgacheffe 250g", 1650], ["Colombia Huila 1kg", 4800]
]
customers = [
  ["Nora Keller", "nora@example.com"], ["Jonas Meier", "jonas@example.com"],
  ["Aline Weber", "aline@example.com"], ["Luca Brunner", "luca@example.com"],
  ["Mia Schneider", "mia@example.com"], ["Tim Baumann", "tim@example.com"]
]

rng = Random.new(42)

40.times do |i|
  name, email = customers[i % customers.size]
  status = Order::STATUSES[rng.rand(4)]
  placed = Time.now - (rng.rand(60 * 24) * 3600)

  order = Order.create!(
    customer_name: name,
    customer_email: email,
    status: status,
    placed_at: placed,
    notes: rng.rand(3).zero? ? "Leave at the door" : nil
  )

  (1 + rng.rand(4)).times do
    product, price = products[rng.rand(products.size)]
    order.line_items.create!(product_name: product, quantity: 1 + rng.rand(3), unit_price_cents: price)
  end
  order.recalculate_total!

  order.order_events.create!(kind: "note", body: "Order received", author: "system", created_at: placed)
  unless status == "pending"
    order.order_events.create!(
      kind: "status_change", from_status: "pending", to_status: status,
      author: "system", created_at: placed + 3600
    )
  end
end

puts "Seeded #{Order.count} orders, #{LineItem.count} line items, #{OrderEvent.count} events"
