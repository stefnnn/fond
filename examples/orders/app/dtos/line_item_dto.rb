# typed: strict

class LineItemDTO < T::Struct
  const :id, Integer
  const :product_name, String
  const :quantity, Integer
  const :unit_price_cents, Integer

  def self.from_model(item)
    new(
      id: item.id,
      product_name: item.product_name,
      quantity: item.quantity,
      unit_price_cents: item.unit_price_cents
    )
  end
end
