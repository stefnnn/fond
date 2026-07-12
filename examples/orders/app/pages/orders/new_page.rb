# typed: strict

module Orders
  class NewPage < Fond::Page
    class Props < T::Struct
      const :suggested_products, T::Array[String]
    end
  end
end
