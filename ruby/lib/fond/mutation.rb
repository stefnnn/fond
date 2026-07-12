# typed: false
# frozen_string_literal: true

module Fond
  # Base class for mutation definitions:
  #
  #   class Orders::CreateMutation < Fond::Mutation
  #     class Params < T::Struct
  #       const :customer_name, String
  #     end
  #
  #     class Props < T::Struct   # optional; most mutations redirect instead
  #       const :order, OrderDTO
  #     end
  #   end
  #
  # Mutation actions return one of:
  #   Fond::Redirect.new("/orders/5")  -> 200 { redirect: ... }
  #   Props instance                   -> 200 { props: ... }
  #   Fond::Done                       -> 200 { props: null }
  #   ActiveModel::Errors / Invalid    -> 422 { errors: { base:, fields: } }
  class Mutation
    class << self
      def inherited(subclass)
        super
        Fond::Registry.register_mutation(subclass)
      end

      # "Orders::CreateMutation" → "orders/create"
      def mutation_name
        name.delete_suffix("Mutation").gsub("::", "/").gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end

      def params_class
        const_defined?(:Params, false) ? const_get(:Params, false) : nil
      end

      def props_class
        const_defined?(:Props, false) ? const_get(:Props, false) : nil
      end
    end
  end

  class Redirect
    attr_reader :url

    def initialize(url)
      @url = url
    end
  end

  # Sentinel for mutations that succeed with nothing to say.
  Done = Object.new.freeze

  # Canonical validation-error shape: base messages + per-field messages.
  # Accepts an ActiveModel::Errors or explicit base:/fields: (snake_case
  # field keys are camelized on the wire).
  class Invalid
    attr_reader :base, :fields

    def initialize(source = nil, base: [], fields: {})
      if source
        @base = source.full_messages_for(:base)
        @fields = source.attribute_names.reject { |a| a == :base }.to_h do |attr|
          [Fond::Naming.camelize(attr), source.full_messages_for(attr)]
        end
      else
        @base = base
        @fields = fields.transform_keys { |k| Fond::Naming.camelize(k) }
      end
    end

    def to_wire
      { "base" => @base, "fields" => @fields }
    end
  end
end
