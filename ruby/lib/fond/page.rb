# typed: false
# frozen_string_literal: true

module Fond
  # Base class for page definitions. Subclasses declare nested T::Structs:
  #
  #   class Orders::IndexPage < Fond::Page
  #     class Params < T::Struct
  #       const :status, T.nilable(OrderStatus)
  #       const :page, Integer, default: 1
  #     end
  #
  #     class Props < T::Struct
  #       const :orders, T::Array[OrderDTO]
  #       const :total_count, Integer
  #     end
  #   end
  #
  # `Params` is optional (pages without inputs), `Props` is required.
  class Page
    class << self
      def inherited(subclass)
        super
        Fond::Registry.register(subclass)
      end

      # "Orders::IndexPage" → "orders/index"
      def component_name
        name.delete_suffix("Page").gsub("::", "/").gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end

      def params_class
        const_defined?(:Params, false) ? const_get(:Params, false) : nil
      end

      def props_class
        raise Fond::Error, "#{name} must define a Props struct" unless const_defined?(:Props, false)

        const_get(:Props, false)
      end
    end
  end
end
