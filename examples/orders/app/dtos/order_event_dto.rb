# typed: strict

class StatusChangeEventDTO < T::Struct
  const :type, String, default: "status_change"
  const :id, Integer
  const :from_status, OrderStatus
  const :to_status, OrderStatus
  const :author, String
  const :created_at, Time
end

class NoteEventDTO < T::Struct
  const :type, String, default: "note"
  const :id, Integer
  const :body, String
  const :author, String
  const :created_at, Time
end

OrderEventDTO = T.type_alias { T.any(StatusChangeEventDTO, NoteEventDTO) }

module OrderEventDTOMapper
  def self.from_model(event)
    case event.kind
    when "status_change"
      StatusChangeEventDTO.new(
        id: event.id,
        from_status: OrderStatus.deserialize(event.from_status),
        to_status: OrderStatus.deserialize(event.to_status),
        author: event.author,
        created_at: event.created_at
      )
    when "note"
      NoteEventDTO.new(
        id: event.id,
        body: event.body.to_s,
        author: event.author,
        created_at: event.created_at
      )
    else
      raise ArgumentError, "unknown event kind #{event.kind}"
    end
  end
end
