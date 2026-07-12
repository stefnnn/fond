# typed: strict

module Orders
  class DestroyMutation < Fond::Mutation
    class Params < T::Struct
      const :id, Integer
    end
  end
end
