# typed: strict

module Orders
  class ShowPage < Fond::Page
    class Params < T::Struct
      const :id, Integer
    end

    class Props < T::Struct
      const :order, OrderDTO
      const :line_items, T::Array[LineItemDTO]
      const :activity, T::Array[OrderEventDTO]
    end
  end
end
