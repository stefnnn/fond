# typed: strict

module Orders
  class CreateMutation < Fond::Mutation
    class LineItemInput < T::Struct
      const :product_name, String
      const :quantity, Integer
      const :unit_price_cents, Integer
    end

    class Params < T::Struct
      const :customer_name, String
      const :customer_email, String
      const :notes, T.nilable(String)
      const :line_items, T::Array[LineItemInput]
    end
  end
end
