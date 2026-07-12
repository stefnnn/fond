# typed: strict

class OrderStatus < T::Enum
  enums do
    Pending = new("pending")
    Paid = new("paid")
    Shipped = new("shipped")
    Cancelled = new("cancelled")
  end
end
