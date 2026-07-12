# typed: strict

module Orders
  class AddNoteMutation < Fond::Mutation
    class Params < T::Struct
      const :id, Integer
      const :body, String
    end
  end
end
