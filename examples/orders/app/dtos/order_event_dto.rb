# typed: strict

OrderEventDTO = T.type_alias { T.any(StatusChangeEventDTO, NoteEventDTO) }
