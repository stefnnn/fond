# typed: strict

class NoteEventDTO < T::Struct
  const :type, String, default: "note"
  const :id, Integer
  const :body, String
  const :author, String
  const :created_at, Time
end
