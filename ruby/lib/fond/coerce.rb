# typed: false
# frozen_string_literal: true

require "date"
require "time"

module Fond
  # Coerces Rails-params-shaped hashes (string/symbol keys, string-ish values)
  # into validated T::Struct instances. T::Struct.from_hash neither coerces
  # nor validates, so we walk klass.props and build kwargs by hand.
  module Coerce
    class Error < Fond::Error
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super(errors.map { |path, message| "#{path}: #{message}" }.join("; "))
      end
    end

    INTEGER_RE = /\A-?\d+\z/.freeze

    class << self
      def struct(klass, hash)
        errors = {}
        instance = coerce_struct(klass, hash, "", errors)
        raise Error, errors unless errors.empty?

        instance
      end

      private

      def coerce_struct(klass, value, path, errors)
        return value if value.is_a?(klass)

        unless value.is_a?(Hash)
          errors[path] = "must be a hash"
          return nil
        end

        local_errors = {}
        kwargs = coerce_struct_props(klass, value, path, local_errors)
        errors.merge!(local_errors)
        return nil unless local_errors.empty?

        begin
          klass.new(**kwargs)
        rescue TypeError => e
          errors[path] = e.message
          nil
        end
      end

      def coerce_struct_props(klass, hash, path, errors)
        input = stringify_keys(hash)
        kwargs = {}

        klass.props.each do |name, prop|
          camel = Fond::Naming.camelize(name)
          key = input.key?(camel) ? camel : name.to_s
          field_path = path.empty? ? camel : "#{path}.#{camel}"

          if input.key?(key)
            kwargs[name] = coerce_value(prop[:type_object], input[key], field_path, errors)
          elsif prop.key?(:default)
            next
          elsif prop[:_tnilable]
            kwargs[name] = nil
          else
            errors[field_path] = "is required"
          end
        end

        kwargs
      end

      def coerce_value(type, value, path, errors)
        case type
        when T::Types::Union
          coerce_union(type, value, path, errors)
        when T::Types::TypedArray
          coerce_array(type, value, path, errors)
        when T::Types::TypedHash
          coerce_hash(type, value, path, errors)
        when T::Types::Untyped
          value
        when T::Types::Simple
          coerce_simple(type.raw_type, value, path, errors)
        else
          value
        end
      end

      def coerce_union(type, value, path, errors)
        types = type.types
        nil_types, non_nil_types = types.partition { |t| simple_raw(t) == NilClass }

        if nil_types.any?
          return nil if value.nil? || value == ""
          return coerce_value(non_nil_types.first, value, path, errors) if non_nil_types.length == 1

          return coerce_union_variants(non_nil_types, value, path, errors)
        end

        if types.length == 2 && types.all? { |t| [TrueClass, FalseClass].include?(simple_raw(t)) }
          return coerce_boolean(value, path, errors)
        end

        coerce_union_variants(types, value, path, errors)
      end

      def coerce_union_variants(types, value, path, errors)
        raw_types = types.map { |t| simple_raw(t) }
        if value.is_a?(Hash) && raw_types.all? { |t| t.is_a?(Class) && t < T::Struct }
          return coerce_discriminated(raw_types, value, path, errors)
        end

        types.each do |t|
          scratch = {}
          result = coerce_value(t, value, path, scratch)
          return result if scratch.empty?
        end

        errors[path] = "does not match any allowed type"
        nil
      end

      def coerce_discriminated(struct_klasses, hash, path, errors)
        input = stringify_keys(hash)

        if input.key?("type")
          match = struct_klasses.find do |k|
            prop = k.props[:type]
            prop && prop.key?(:default) && prop[:default] == input["type"]
          end
          return coerce_struct(match, hash, path, errors) if match
        end

        struct_klasses.each do |k|
          scratch = {}
          result = coerce_struct(k, hash, path, scratch)
          return result if scratch.empty?
        end

        errors[path] = "does not match any known type"
        nil
      end

      def coerce_array(type, value, path, errors)
        unless value.is_a?(Array)
          errors[path] = "must be an array"
          return nil
        end

        value.each_with_index.map { |v, i| coerce_value(type.type, v, "#{path}.#{i}", errors) }
      end

      def coerce_hash(type, value, path, errors)
        unless value.is_a?(Hash)
          errors[path] = "must be a hash"
          return nil
        end

        value.each_with_object({}) do |(k, v), result|
          entry_path = "#{path}.#{k}"
          coerced_key = coerce_value(type.keys, k, entry_path, errors)
          coerced_value = coerce_value(type.values, v, entry_path, errors)
          result[coerced_key] = coerced_value
        end
      end

      def coerce_simple(raw_type, value, path, errors)
        return coerce_integer(value, path, errors) if raw_type == Integer
        return coerce_float(value, path, errors) if raw_type == Float
        return coerce_string(value, path, errors) if raw_type == String
        return coerce_symbol(value, path, errors) if raw_type == Symbol
        return coerce_date(value, path, errors) if raw_type == Date
        return coerce_datetime(value, path, errors) if raw_type == DateTime
        return coerce_time(value, path, errors) if raw_type == Time
        return coerce_boolean(value, path, errors) if [TrueClass, FalseClass].include?(raw_type)
        return coerce_enum(raw_type, value, path, errors) if raw_type.is_a?(Class) && raw_type < T::Enum
        return coerce_struct(raw_type, value, path, errors) if raw_type.is_a?(Class) && raw_type < T::Struct

        value
      end

      def coerce_integer(value, path, errors)
        return value if value.is_a?(Integer)
        return value.to_i if value.is_a?(String) && INTEGER_RE.match?(value)

        errors[path] = "must be an integer"
        nil
      end

      def coerce_float(value, path, errors)
        return value.to_f if value.is_a?(Numeric)

        if value.is_a?(String)
          begin
            return Float(value)
          rescue ArgumentError
            nil
          end
        end

        errors[path] = "must be a number"
        nil
      end

      def coerce_string(value, path, errors)
        return value if value.is_a?(String)

        errors[path] = "must be a string"
        nil
      end

      def coerce_symbol(value, path, errors)
        return value.to_sym if value.is_a?(String) || value.is_a?(Symbol)

        errors[path] = "must be a symbol"
        nil
      end

      def coerce_boolean(value, path, errors)
        return value if value == true || value == false
        return true if ["true", "1"].include?(value)
        return false if ["false", "0"].include?(value)

        errors[path] = "must be a boolean"
        nil
      end

      def coerce_date(value, path, errors)
        return value if value.is_a?(Date)

        if value.is_a?(String)
          begin
            return Date.iso8601(value)
          rescue ArgumentError
            nil
          end
        end

        errors[path] = "must be an ISO8601 date"
        nil
      end

      def coerce_time(value, path, errors)
        return value if value.is_a?(Time)

        if value.is_a?(String)
          begin
            return Time.iso8601(value)
          rescue ArgumentError
            nil
          end
        end

        errors[path] = "must be an ISO8601 time"
        nil
      end

      def coerce_datetime(value, path, errors)
        return value if value.is_a?(DateTime)

        if value.is_a?(String)
          begin
            return DateTime.iso8601(value)
          rescue ArgumentError
            nil
          end
        end

        errors[path] = "must be an ISO8601 datetime"
        nil
      end

      def coerce_enum(klass, value, path, errors)
        return value if value.is_a?(klass)

        if value.is_a?(String)
          begin
            return klass.deserialize(value)
          rescue KeyError
            nil
          end
        end

        errors[path] = "must be one of #{klass.values.map(&:serialize).join(', ')}"
        nil
      end

      def simple_raw(type)
        type.is_a?(T::Types::Simple) ? type.raw_type : nil
      end

      def stringify_keys(hash)
        hash.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
      end
    end
  end
end
