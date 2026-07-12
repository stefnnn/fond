# typed: strict

module Orders
  class UpdateStatusMutation < Fond::Mutation
    class Params < T::Struct
      const :id, Integer
      const :status, OrderStatus
    end
  end
end
