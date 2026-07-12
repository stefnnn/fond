# typed: strict

class SharedProps < T::Struct
  class Flash < T::Struct
    const :notice, T.nilable(String)
    const :alert, T.nilable(String)
  end

  const :app_name, String
  const :flash, Flash
  const :open_order_count, Integer
end
