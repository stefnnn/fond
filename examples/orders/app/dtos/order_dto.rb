# typed: strict

class OrderDTO < T::Struct
  const :id, Integer
  const :customer_name, String
  const :customer_email, String
  const :status, OrderStatus
  const :total_cents, Integer
  const :placed_at, Time
  const :notes, T.nilable(String)

  def self.from_model(order)
    new(
      id: order.id,
      customer_name: order.customer_name,
      customer_email: order.customer_email,
      status: OrderStatus.deserialize(order.status),
      total_cents: order.total_cents,
      placed_at: order.placed_at,
      notes: order.notes
    )
  end
end
