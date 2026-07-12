# frozen_string_literal: true

require_relative "test_helper"
require "bigdecimal"

module SerializeTest
  class Status < T::Enum
    enums do
      Active = new("active")
    end
  end

  class Leaf < T::Struct
    const :at, Time
    const :on, Date
    const :sym, Symbol
    const :status, Status
  end

  class Root < T::Struct
    const :leaves, T::Array[Leaf]
    const :nested, T.nilable(Leaf)
  end
end

class SerializeTimeTest < Minitest::Test
  def test_serializes_time_to_iso8601_millis_utc
    t = Time.new(2020, 1, 2, 3, 4, 5.123, "+02:00")
    assert_equal("2020-01-02T01:04:05.123Z", Fond::Serialize.to_wire(t))
  end
end

class SerializeDateTimeTest < Minitest::Test
  def test_serializes_datetime_to_iso8601_millis_utc
    dt = DateTime.new(2020, 1, 2, 3, 4, 5, "+2")
    assert_equal("2020-01-02T01:04:05.000Z", Fond::Serialize.to_wire(dt))
  end
end

class SerializeDateTest < Minitest::Test
  def test_serializes_date_to_iso8601
    assert_equal("2020-01-02", Fond::Serialize.to_wire(Date.new(2020, 1, 2)))
  end
end

class SerializeSymbolTest < Minitest::Test
  def test_serializes_symbol_to_string
    assert_equal("hi", Fond::Serialize.to_wire(:hi))
  end
end

class SerializeBigDecimalTest < Minitest::Test
  def test_serializes_bigdecimal_to_string
    assert_equal(BigDecimal("1.5").to_s, Fond::Serialize.to_wire(BigDecimal("1.5")))
  end
end

class SerializePlainValueTest < Minitest::Test
  def test_passes_through_primitives
    assert_equal(1, Fond::Serialize.to_wire(1))
    assert_equal(1.5, Fond::Serialize.to_wire(1.5))
    assert_equal("hi", Fond::Serialize.to_wire("hi"))
    assert_nil(Fond::Serialize.to_wire(nil))
    assert_equal(true, Fond::Serialize.to_wire(true))
  end
end

class SerializeHashAndArrayTest < Minitest::Test
  def test_recurses_into_plain_hash_and_array
    input = { a: 1, "b" => [Date.new(2020, 1, 1), :sym, { c: Time.utc(2020, 1, 1) }] }
    result = Fond::Serialize.to_wire(input)

    assert_equal(
      { "a" => 1, "b" => ["2020-01-01", "sym", { "c" => "2020-01-01T00:00:00.000Z" }] },
      result
    )
  end

  def test_stringifies_symbol_hash_keys
    result = Fond::Serialize.to_wire({ foo: 1 })
    assert_equal({ "foo" => 1 }, result)
  end

  def test_serializes_a_raw_struct_nested_in_a_plain_hash
    leaf = SerializeTest::Leaf.new(at: Time.utc(2020, 1, 1), on: Date.new(2020, 1, 1), sym: :x,
                                    status: SerializeTest::Status::Active)
    result = Fond::Serialize.to_wire({ item: leaf })

    assert_equal(
      { "item" => { "at" => "2020-01-01T00:00:00.000Z", "on" => "2020-01-01", "sym" => "x", "status" => "active" } },
      result
    )
  end
end

class SerializeStructTest < Minitest::Test
  def test_serializes_nested_struct_tree_including_temporals_in_arrays
    leaves = [
      SerializeTest::Leaf.new(at: Time.utc(2020, 1, 1, 1, 2, 3), on: Date.new(2020, 1, 1), sym: :a,
                               status: SerializeTest::Status::Active),
      SerializeTest::Leaf.new(at: Time.utc(2020, 2, 2, 1, 2, 3), on: Date.new(2020, 2, 2), sym: :b,
                               status: SerializeTest::Status::Active)
    ]
    root = SerializeTest::Root.new(leaves: leaves, nested: nil)

    result = Fond::Serialize.to_wire(root)

    assert_equal(2, result["leaves"].length)
    assert_equal("2020-01-01T01:02:03.000Z", result["leaves"][0]["at"])
    assert_equal("2020-01-01", result["leaves"][0]["on"])
    assert_equal("a", result["leaves"][0]["sym"])
    assert_equal("active", result["leaves"][0]["status"])
    assert_nil(result["nested"])
  end

  def test_iso8601_round_trip_through_serialize
    original = Time.now.utc.round(3)
    leaf = SerializeTest::Leaf.new(at: original, on: Date.today, sym: :x, status: SerializeTest::Status::Active)

    wire = Fond::Serialize.to_wire(leaf)
    round_tripped = Time.iso8601(wire["at"])

    assert_equal(original, round_tripped)
  end
end
