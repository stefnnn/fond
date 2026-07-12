# frozen_string_literal: true

require_relative "test_helper"

class TsEmitterTest < Minitest::Test
  def setup
    Fond::Registry.reset!
    @emitter = Fond::Codegen::TsEmitter.new(name_for: ->(klass) { klass.name.gsub("::", "") })
  end

  def type_of(struct_class, field)
    struct_class.props[field][:type_object]
  end

  def test_number_types
    klass = Class.new(T::Struct) do
      const :a, Integer
      const :b, Float
      const :c, Numeric
    end
    assert_equal "number", @emitter.emit(type_of(klass, :a))
    assert_equal "number", @emitter.emit(type_of(klass, :b))
    assert_equal "number", @emitter.emit(type_of(klass, :c))
  end

  def test_string_types
    klass = Class.new(T::Struct) do
      const :a, String
      const :b, Symbol
    end
    assert_equal "string", @emitter.emit(type_of(klass, :a))
    assert_equal "string", @emitter.emit(type_of(klass, :b))
  end

  def test_boolean_types
    klass = Class.new(T::Struct) do
      const :a, T::Boolean
    end
    assert_equal "boolean", @emitter.emit(type_of(klass, :a))
  end

  def test_nil_class
    klass = Class.new(T::Struct) do
      const :a, T.nilable(String)
    end
    nilable = type_of(klass, :a)
    nil_member = nilable.types.find { |t| t.raw_type == NilClass }
    assert_equal "null", @emitter.emit(nil_member)
  end

  def test_date_and_time_types
    klass = Class.new(T::Struct) do
      const :a, Date
      const :b, Time
      const :c, DateTime
    end
    assert_equal "ISODate", @emitter.emit(type_of(klass, :a))
    assert @emitter.uses_date?
    assert_equal "ISODateTime", @emitter.emit(type_of(klass, :b))
    assert_equal "ISODateTime", @emitter.emit(type_of(klass, :c))
    assert @emitter.uses_date_time?
  end

  def test_nilable_simple
    klass = Class.new(T::Struct) do
      const :a, T.nilable(String)
    end
    assert_equal "string | null", @emitter.emit(type_of(klass, :a))
  end

  def test_nilable_union_is_parenthesized
    klass = Class.new(T::Struct) do
      const :a, T.nilable(T.any(Integer, String))
    end
    assert_equal "(number | string) | null", @emitter.emit(type_of(klass, :a))
  end

  def test_union_dedup_and_sorted
    klass = Class.new(T::Struct) do
      const :a, T.any(String, Symbol, Integer)
    end
    # String and Symbol both map to "string" and should dedup; sorted alphabetically
    assert_equal "number | string", @emitter.emit(type_of(klass, :a))
  end

  def test_union_boolean_collapses_first
    klass = Class.new(T::Struct) do
      const :a, T.any(TrueClass, FalseClass, Integer)
    end
    assert_equal "boolean | number", @emitter.emit(type_of(klass, :a))
  end

  def test_typed_array
    klass = Class.new(T::Struct) do
      const :a, T::Array[Integer]
    end
    assert_equal "number[]", @emitter.emit(type_of(klass, :a))
  end

  def test_typed_array_of_union_is_parenthesized
    klass = Class.new(T::Struct) do
      const :a, T::Array[T.any(Integer, String)]
    end
    assert_equal "(number | string)[]", @emitter.emit(type_of(klass, :a))
  end

  def test_typed_set
    klass = Class.new(T::Struct) do
      const :a, T::Set[String]
    end
    assert_equal "string[]", @emitter.emit(type_of(klass, :a))
  end

  def test_typed_hash_string_and_symbol_keys
    klass = Class.new(T::Struct) do
      const :a, T::Hash[String, Integer]
      const :b, T::Hash[Symbol, Integer]
    end
    assert_equal "Record<string, number>", @emitter.emit(type_of(klass, :a))
    assert_equal "Record<string, number>", @emitter.emit(type_of(klass, :b))
  end

  def test_typed_hash_integer_keys
    klass = Class.new(T::Struct) do
      const :a, T::Hash[Integer, String]
    end
    assert_equal "Record<number, string>", @emitter.emit(type_of(klass, :a))
  end

  def test_typed_hash_union_value_is_parenthesized
    klass = Class.new(T::Struct) do
      const :a, T::Hash[String, T.any(Integer, String)]
    end
    assert_equal "Record<string, (number | string)>", @emitter.emit(type_of(klass, :a))
  end

  def test_struct_reference_and_recording
    dto = Class.new(T::Struct) do
      const :id, Integer
    end
    Object.const_set(:TsEmitterTestDTO, dto)
    klass = Class.new(T::Struct) do
      const :a, TsEmitterTestDTO
    end
    assert_equal "TsEmitterTestDTO", @emitter.emit(type_of(klass, :a))
    assert_includes @emitter.referenced, TsEmitterTestDTO
  ensure
    Object.send(:remove_const, :TsEmitterTestDTO) if Object.const_defined?(:TsEmitterTestDTO)
  end

  class TsEmitterTestEnum < T::Enum
    enums do
      A = new("a")
    end
  end

  def test_enum_reference_and_recording
    klass = Class.new(T::Struct) do
      const :a, TsEmitterTestEnum
    end
    assert_equal "TsEmitterTestTsEmitterTestEnum", @emitter.emit(type_of(klass, :a))
    assert_includes @emitter.referenced, TsEmitterTestEnum
  end

  def test_untyped
    klass = Class.new(T::Struct) do
      const :a, T.untyped
    end
    assert_equal "unknown", @emitter.emit(type_of(klass, :a))
  end

  def test_fixed_hash_shape
    klass = Class.new(T::Struct) do
      const :a, {name: String, age: Integer}
    end
    assert_equal "{ name: string; age: number }", @emitter.emit(type_of(klass, :a))
  end

  def test_unrecognized_type_raises
    klass = Class.new(T::Struct) do
      const :a, T.class_of(String)
    end
    error = assert_raises(Fond::Error) { @emitter.emit(type_of(klass, :a)) }
    assert_match(/ClassOf/, error.message)
  end

  class GnarlyStatus < T::Enum
    enums do
      OPEN = new("open")
      CLOSED = new("closed")
    end
  end

  def test_gnarly_nested_case
    shipped = Class.new(T::Struct) do
      const :type, String, default: "shipped"
      const :status, T.nilable(GnarlyStatus)
      const :meta, T::Hash[String, Integer]
    end
    Object.const_set(:GnarlyShipped, shipped)

    cancelled = Class.new(T::Struct) do
      const :type, String, default: "cancelled"
      const :status, T.nilable(GnarlyStatus)
      const :reason, String
    end
    Object.const_set(:GnarlyCancelled, cancelled)

    holder = Class.new(T::Struct) do
      const :events, T::Array[T.any(GnarlyShipped, GnarlyCancelled)]
    end

    ts = @emitter.emit(type_of(holder, :events))
    assert_equal "(GnarlyCancelled | GnarlyShipped)[]", ts
    assert_includes @emitter.referenced, GnarlyShipped
    assert_includes @emitter.referenced, GnarlyCancelled

    status_ts = @emitter.emit(type_of(shipped, :status))
    assert_equal "TsEmitterTestGnarlyStatus | null", status_ts
    assert_includes @emitter.referenced, GnarlyStatus
  ensure
    %i[GnarlyShipped GnarlyCancelled].each do |c|
      Object.send(:remove_const, c) if Object.const_defined?(c)
    end
  end
end
