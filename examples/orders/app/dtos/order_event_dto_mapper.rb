# typed: strict

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
