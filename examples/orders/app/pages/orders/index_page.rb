# typed: strict

module Orders
  class IndexPage < Fond::Page
    class Params < T::Struct
      const :status, T.nilable(OrderStatus)
      const :query, T.nilable(String)
      const :page, Integer, default: 1
    end

    class Props < T::Struct
      const :orders, T::Array[OrderDTO]
      const :total_count, Integer
      const :page, Integer
      const :per_page, Integer
      const :status_counts, T::Hash[String, Integer]
    end
  end
end
