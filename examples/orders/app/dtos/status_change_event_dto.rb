# typed: strict

class StatusChangeEventDTO < T::Struct
  const :type, String, default: "status_change"
  const :id, Integer
  const :from_status, OrderStatus
  const :to_status, OrderStatus
  const :author, String
  const :created_at, Time
end
