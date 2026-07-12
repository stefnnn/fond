# typed: false
# frozen_string_literal: true

begin
  require "bigdecimal"
rescue LoadError
  nil
end

module Fond
  # Turns T::Struct instances (and plain Hash/Array trees) into JSON-ready
  # data with camelCase keys matching the generated TypeScript types.
  # Structs are walked prop-by-prop (not via #serialize) so nested structs
  # keep their identity until their own keys are camelized; plain Hash keys
  # are user data and stay untouched.
  module Serialize
    class << self
      def to_wire(value)
        case value
        when T::Struct
          value.class.props.keys.each_with_object({}) do |name, acc|
            acc[Fond::Naming.camelize(name)] = to_wire(value.send(name))
          end
        when T::Enum
          value.serialize
        when Hash
          value.each_with_object({}) { |(k, v), acc| acc[to_wire_key(k)] = to_wire(v) }
        when Array
          value.map { |v| to_wire(v) }
        when Time
          value.getutc.iso8601(3)
        when DateTime
          value.to_time.getutc.iso8601(3)
        when Date
          value.iso8601
        when Symbol
          value.to_s
        else
          if defined?(BigDecimal) && value.is_a?(BigDecimal)
            value.to_s
          else
            value
          end
        end
      end

      private

      def to_wire_key(key)
        key.is_a?(Symbol) ? key.to_s : key
      end
    end
  end
end
