# typed: false
# frozen_string_literal: true

require "set"
require "date"

module Fond
  module Codegen
    # Converts a T::Types::Base type tree into a TypeScript type expression,
    # collecting every T::Struct/T::Enum class it encounters along the way.
    class TsEmitter
      attr_reader :referenced

      def initialize(name_for:)
        @name_for = name_for
        @referenced = Set.new
        @uses_date = false
        @uses_date_time = false
      end

      def uses_date?
        @uses_date
      end

      def uses_date_time?
        @uses_date_time
      end

      def emit(type)
        case type
        when T::Types::TypedArray
          emit_array(type)
        when T::Types::TypedSet
          emit_set(type)
        when T::Types::TypedHash
          emit_hash(type)
        when T::Types::FixedHash
          emit_fixed_hash(type)
        when T::Types::Union
          emit_union(type)
        when T::Types::Simple
          emit_simple(type)
        when T::Types::Untyped
          "unknown"
        else
          raise Fond::Error, "fond: cannot map #{type.inspect} to a TypeScript type"
        end
      end

      private

      def emit_simple(type)
        raw = type.raw_type

        return "number" if [Integer, Float, Numeric].include?(raw)
        return "string" if [String, Symbol].include?(raw)
        return "boolean" if [TrueClass, FalseClass].include?(raw)
        return "null" if raw == NilClass

        if raw == Date
          @uses_date = true
          return "ISODate"
        end

        if [Time, DateTime].include?(raw)
          @uses_date_time = true
          return "ISODateTime"
        end

        if raw.is_a?(Class) && raw < T::Struct
          @referenced << raw
          return @name_for.call(raw)
        end

        if raw.is_a?(Class) && raw < T::Enum
          @referenced << raw
          return @name_for.call(raw)
        end

        raise Fond::Error, "fond: cannot map #{raw} to a TypeScript type"
      end

      def emit_array(type)
        parenthesize_if_union(emit(type.type)) + "[]"
      end

      def emit_set(type)
        parenthesize_if_union(emit(type.type)) + "[]"
      end

      def emit_hash(type)
        key = emit(type.keys)
        value = parenthesize_if_union(emit(type.values))
        "Record<#{key}, #{value}>"
      end

      def emit_fixed_hash(type)
        fields = type.types.map { |name, member_type| "#{name}: #{emit(member_type)}" }
        "{ #{fields.join('; ')} }"
      end

      def emit_union(type)
        members = type.types
        nil_member = members.find { |t| simple_raw(t) == NilClass }

        return union_body(members) unless nil_member

        non_nil = members - [nil_member]
        body = union_body(non_nil)
        body = "(#{body})" if body.include?(" | ")
        "#{body} | null"
      end

      def union_body(types)
        raws = types.map { |t| simple_raw(t) }
        strings = []

        if raws.include?(TrueClass) && raws.include?(FalseClass)
          strings << "boolean"
          types = types.reject { |t| [TrueClass, FalseClass].include?(simple_raw(t)) }
        end

        strings += types.map { |t| emit(t) }
        strings.uniq.sort.join(" | ")
      end

      def simple_raw(type)
        type.is_a?(T::Types::Simple) ? type.raw_type : nil
      end

      def parenthesize_if_union(ts_expression)
        ts_expression.include?(" | ") ? "(#{ts_expression})" : ts_expression
      end
    end
  end
end
