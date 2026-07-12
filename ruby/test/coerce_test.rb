# frozen_string_literal: true

require_relative "test_helper"

module CoerceTest
  class Status < T::Enum
    enums do
      Active = new("active")
      Inactive = new("inactive")
    end
  end

  class Addr < T::Struct
    const :city, String
    const :zip, T.nilable(Integer)
  end

  class Item < T::Struct
    const :name, String
    const :price, Float
    const :qty, Integer, default: 1
  end

  class VariantA < T::Struct
    const :type, String, default: "a"
    const :value, Integer
  end

  class VariantB < T::Struct
    const :type, String, default: "b"
    const :label, String
  end

  class Big < T::Struct
    const :status, T.nilable(Status)
    const :addr, Addr
    const :items, T::Array[Item]
    const :variant, T.any(VariantA, VariantB)
    const :flag, T::Boolean, default: false
    const :tag, Symbol
    const :meta, T::Hash[String, Integer]
    const :when, Date
  end

  class Simple < T::Struct
    const :name, String
    const :count, Integer, default: 5
    const :nickname, T.nilable(String)
    const :active, T::Boolean, default: true
  end

  class Basics < T::Struct
    const :i, Integer
    const :f, Float
    const :s, String
    const :sym, Symbol
    const :d, Date
    const :t, Time
    const :dt, DateTime
    const :untyped, T.untyped
  end
end

class CoerceIntegrationTest < Minitest::Test
  def good_input
    {
      status: "active",
      addr: { city: "NYC", zip: "10001" },
      items: [{ name: "a", price: "1.5" }, { name: "b", price: 2, qty: "3" }],
      variant: { type: "b", label: "hi" },
      flag: "true",
      tag: "x",
      meta: { "a" => "1", "b" => "2" },
      when: "2020-01-02"
    }
  end

  def test_coerces_a_gnarly_nested_struct
    result = Fond::Coerce.struct(CoerceTest::Big, good_input)

    assert_instance_of(CoerceTest::Big, result)
    assert_equal(CoerceTest::Status::Active, result.status)
    assert_instance_of(CoerceTest::Addr, result.addr)
    assert_equal(10_001, result.addr.zip)
    assert_equal(2, result.items.length)
    assert_in_delta(1.5, result.items[0].price)
    assert_equal(1, result.items[0].qty)
    assert_equal(3, result.items[1].qty)
    assert_instance_of(CoerceTest::VariantB, result.variant)
    assert_equal("hi", result.variant.label)
    assert_equal(true, result.flag)
    assert_equal(:x, result.tag)
    assert_equal({ "a" => 1, "b" => 2 }, result.meta)
    assert_equal(Date.iso8601("2020-01-02"), result.when)
  end

  def test_accumulates_all_errors_with_dotted_paths_in_one_pass
    bad = {
      status: "bogus",
      addr: { city: 5 },
      items: [{ name: 1, price: "nope" }],
      variant: { type: "z" },
      flag: "nope",
      tag: "x",
      meta: { "a" => "not-a-number" },
      when: "2020-01-02"
    }

    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Big, bad) }

    assert_equal("must be one of active, inactive", error.errors["status"])
    assert_equal("must be a string", error.errors["addr.city"])
    assert_equal("must be a string", error.errors["items.0.name"])
    assert_equal("must be a number", error.errors["items.0.price"])
    assert_equal("does not match any known type", error.errors["variant"])
    assert_equal("must be a boolean", error.errors["flag"])
    assert_equal("must be an integer", error.errors["meta.a"])
  end

  def test_error_is_a_fond_error
    assert_kind_of(Fond::Error, Fond::Coerce::Error.new({}))
  end
end

class CoerceIntegerTest < Minitest::Test
  def test_accepts_integer
    assert_equal(3, Fond::Coerce.struct(CoerceTest::Basics, basics(i: 3)).i)
  end

  def test_coerces_integer_string
    assert_equal(3, Fond::Coerce.struct(CoerceTest::Basics, basics(i: "3")).i)
  end

  def test_coerces_negative_integer_string
    assert_equal(-3, Fond::Coerce.struct(CoerceTest::Basics, basics(i: "-3")).i)
  end

  def test_rejects_non_integer_string
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Basics, basics(i: "3.5")) }
    assert_equal("must be an integer", error.errors["i"])
  end

  def test_rejects_other_types
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Basics, basics(i: true)) }
    assert_equal("must be an integer", error.errors["i"])
  end

  private

  def basics(overrides = {})
    {
      i: 1, f: 1.0, s: "s", sym: :s, d: "2020-01-01", t: "2020-01-01T00:00:00Z",
      dt: "2020-01-01T00:00:00Z", untyped: 1
    }.merge(overrides)
  end
end

class CoerceFloatTest < Minitest::Test
  def test_accepts_numeric
    assert_in_delta(1.0, coerce_float(1))
    assert_in_delta(1.5, coerce_float(1.5))
  end

  def test_coerces_numeric_string
    assert_in_delta(1.5, coerce_float("1.5"))
    assert_in_delta(2.0, coerce_float("2"))
  end

  def test_rejects_non_numeric_string
    error = assert_raises(Fond::Coerce::Error) { coerce_float("nope") }
    assert_equal("must be a number", error.errors["f"])
  end

  private

  def coerce_float(value)
    Fond::Coerce.struct(CoerceTest::Basics, basics(f: value)).f
  end

  def basics(overrides = {})
    {
      i: 1, f: 1.0, s: "s", sym: :s, d: "2020-01-01", t: "2020-01-01T00:00:00Z",
      dt: "2020-01-01T00:00:00Z", untyped: 1
    }.merge(overrides)
  end
end

class CoerceStringTest < Minitest::Test
  def test_accepts_string
    assert_equal("hi", Fond::Coerce.struct(CoerceTest::Basics, basics(s: "hi")).s)
  end

  def test_rejects_numeric_for_string
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Basics, basics(s: 5)) }
    assert_equal("must be a string", error.errors["s"])
  end

  private

  def basics(overrides = {})
    {
      i: 1, f: 1.0, s: "s", sym: :s, d: "2020-01-01", t: "2020-01-01T00:00:00Z",
      dt: "2020-01-01T00:00:00Z", untyped: 1
    }.merge(overrides)
  end
end

class CoerceSymbolTest < Minitest::Test
  def test_coerces_string_and_symbol
    assert_equal(:hi, Fond::Coerce.struct(CoerceTest::Basics, basics(sym: "hi")).sym)
    assert_equal(:hi, Fond::Coerce.struct(CoerceTest::Basics, basics(sym: :hi)).sym)
  end

  def test_rejects_other_types
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Basics, basics(sym: 5)) }
    assert_equal("must be a symbol", error.errors["sym"])
  end

  private

  def basics(overrides = {})
    {
      i: 1, f: 1.0, s: "s", sym: :s, d: "2020-01-01", t: "2020-01-01T00:00:00Z",
      dt: "2020-01-01T00:00:00Z", untyped: 1
    }.merge(overrides)
  end
end

class CoerceBooleanTest < Minitest::Test
  def test_accepts_ruby_booleans
    assert_equal(true, Fond::Coerce.struct(CoerceTest::Simple, simple(active: true)).active)
    assert_equal(false, Fond::Coerce.struct(CoerceTest::Simple, simple(active: false)).active)
  end

  def test_coerces_stringy_booleans
    assert_equal(true, Fond::Coerce.struct(CoerceTest::Simple, simple(active: "true")).active)
    assert_equal(true, Fond::Coerce.struct(CoerceTest::Simple, simple(active: "1")).active)
    assert_equal(false, Fond::Coerce.struct(CoerceTest::Simple, simple(active: "false")).active)
    assert_equal(false, Fond::Coerce.struct(CoerceTest::Simple, simple(active: "0")).active)
  end

  def test_rejects_other_strings
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Simple, simple(active: "yes")) }
    assert_equal("must be a boolean", error.errors["active"])
  end

  private

  def simple(overrides = {})
    { name: "a" }.merge(overrides)
  end
end

class CoerceDateTimeTest < Minitest::Test
  def test_accepts_date_instance
    assert_equal(Date.new(2020, 1, 1), Fond::Coerce.struct(CoerceTest::Basics, basics(d: Date.new(2020, 1, 1))).d)
  end

  def test_coerces_iso8601_date_string
    assert_equal(Date.new(2020, 1, 2), Fond::Coerce.struct(CoerceTest::Basics, basics(d: "2020-01-02")).d)
  end

  def test_rejects_invalid_date_string
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Basics, basics(d: "not-a-date")) }
    assert_equal("must be an ISO8601 date", error.errors["d"])
  end

  def test_coerces_iso8601_time_string
    result = Fond::Coerce.struct(CoerceTest::Basics, basics(t: "2020-01-02T03:04:05Z")).t
    assert_instance_of(Time, result)
  end

  def test_rejects_invalid_time_string
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Basics, basics(t: "nope")) }
    assert_equal("must be an ISO8601 time", error.errors["t"])
  end

  def test_coerces_iso8601_datetime_string
    result = Fond::Coerce.struct(CoerceTest::Basics, basics(dt: "2020-01-02T03:04:05Z")).dt
    assert_instance_of(DateTime, result)
  end

  def test_rejects_invalid_datetime_string
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Basics, basics(dt: "nope")) }
    assert_equal("must be an ISO8601 datetime", error.errors["dt"])
  end

  private

  def basics(overrides = {})
    {
      i: 1, f: 1.0, s: "s", sym: :s, d: "2020-01-01", t: "2020-01-01T00:00:00Z",
      dt: "2020-01-01T00:00:00Z", untyped: 1
    }.merge(overrides)
  end
end

class CoerceEnumTest < Minitest::Test
  class WithEnum < T::Struct
    const :status, CoerceTest::Status
  end

  class WithNilableEnum < T::Struct
    const :status, T.nilable(CoerceTest::Status)
  end

  def test_accepts_enum_instance
    result = Fond::Coerce.struct(WithEnum, { status: CoerceTest::Status::Active })
    assert_equal(CoerceTest::Status::Active, result.status)
  end

  def test_deserializes_valid_string
    result = Fond::Coerce.struct(WithEnum, { status: "inactive" })
    assert_equal(CoerceTest::Status::Inactive, result.status)
  end

  def test_rejects_invalid_string
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(WithEnum, { status: "bogus" }) }
    assert_equal("must be one of active, inactive", error.errors["status"])
  end

  def test_nilable_enum_from_empty_string_is_nil
    result = Fond::Coerce.struct(WithNilableEnum, { status: "" })
    assert_nil(result.status)
  end

  def test_nilable_enum_from_nil_is_nil
    result = Fond::Coerce.struct(WithNilableEnum, { status: nil })
    assert_nil(result.status)
  end

  def test_nilable_enum_from_valid_string
    result = Fond::Coerce.struct(WithNilableEnum, { status: "active" })
    assert_equal(CoerceTest::Status::Active, result.status)
  end

  def test_nilable_enum_from_invalid_string_errors
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(WithNilableEnum, { status: "bogus" }) }
    assert_equal("must be one of active, inactive", error.errors["status"])
  end
end

class CoerceNilableTest < Minitest::Test
  def test_missing_key_uses_nil
    result = Fond::Coerce.struct(CoerceTest::Simple, { name: "a" })
    assert_nil(result.nickname)
  end

  def test_nil_stays_nil
    result = Fond::Coerce.struct(CoerceTest::Simple, { name: "a", nickname: nil })
    assert_nil(result.nickname)
  end

  def test_empty_string_becomes_nil
    result = Fond::Coerce.struct(CoerceTest::Simple, { name: "a", nickname: "" })
    assert_nil(result.nickname)
  end

  def test_present_value_is_coerced
    result = Fond::Coerce.struct(CoerceTest::Simple, { name: "a", nickname: "bob" })
    assert_equal("bob", result.nickname)
  end
end

class CoerceArrayTest < Minitest::Test
  class WithArray < T::Struct
    const :nums, T::Array[Integer]
  end

  def test_coerces_each_element
    result = Fond::Coerce.struct(WithArray, { nums: ["1", "2", 3] })
    assert_equal([1, 2, 3], result.nums)
  end

  def test_rejects_non_array
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(WithArray, { nums: "not-an-array" }) }
    assert_equal("must be an array", error.errors["nums"])
  end

  def test_reports_element_index_in_error_path
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(WithArray, { nums: [1, "bad", 3] }) }
    assert_equal("must be an integer", error.errors["nums.1"])
  end
end

class CoerceHashTest < Minitest::Test
  class WithHash < T::Struct
    const :scores, T::Hash[String, Integer]
  end

  def test_coerces_keys_and_values
    result = Fond::Coerce.struct(WithHash, { scores: { "a" => "1", "b" => 2 } })
    assert_equal({ "a" => 1, "b" => 2 }, result.scores)
  end

  def test_rejects_non_hash
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(WithHash, { scores: [] }) }
    assert_equal("must be a hash", error.errors["scores"])
  end
end

class CoerceNestedStructTest < Minitest::Test
  def test_recurses_into_nested_struct
    result = Fond::Coerce.struct(CoerceTest::Addr, { city: "NYC", zip: "1" })
    assert_instance_of(CoerceTest::Addr, result)
    assert_equal(1, result.zip)
  end

  def test_accepts_already_instantiated_struct
    addr = CoerceTest::Addr.new(city: "NYC", zip: nil)
    result = Fond::Coerce.struct(CoerceTest::Addr, addr)
    assert_same(addr, result)
  end

  def test_errors_use_dotted_path_prefix
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Addr, { city: 5 }) }
    assert_equal("must be a string", error.errors["city"])
  end
end

class CoerceUnionTest < Minitest::Test
  class Wrapper < T::Struct
    const :variant, T.any(CoerceTest::VariantA, CoerceTest::VariantB)
  end

  def test_discriminates_by_type_default_a
    result = Fond::Coerce.struct(Wrapper, { variant: { type: "a", value: "5" } })
    assert_instance_of(CoerceTest::VariantA, result.variant)
    assert_equal(5, result.variant.value)
  end

  def test_discriminates_by_type_default_b
    result = Fond::Coerce.struct(Wrapper, { variant: { type: "b", label: "hi" } })
    assert_instance_of(CoerceTest::VariantB, result.variant)
    assert_equal("hi", result.variant.label)
  end

  def test_falls_back_to_trying_variants_in_order_without_type_key
    result = Fond::Coerce.struct(Wrapper, { variant: { label: "hi" } })
    assert_instance_of(CoerceTest::VariantB, result.variant)
  end

  def test_errors_when_no_variant_matches
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(Wrapper, { variant: { type: "z" } }) }
    assert_equal("does not match any known type", error.errors["variant"])
  end
end

class CoerceMissingKeysTest < Minitest::Test
  def test_default_applied_when_key_missing
    result = Fond::Coerce.struct(CoerceTest::Simple, { name: "a" })
    assert_equal(5, result.count)
    assert_equal(true, result.active)
  end

  def test_required_key_missing_errors
    error = assert_raises(Fond::Coerce::Error) { Fond::Coerce.struct(CoerceTest::Simple, {}) }
    assert_equal("is required", error.errors["name"])
  end

  def test_unknown_input_keys_are_ignored
    result = Fond::Coerce.struct(CoerceTest::Simple, { name: "a", bogus: "whatever" })
    assert_equal("a", result.name)
  end

  def test_accepts_string_and_symbol_keys
    result = Fond::Coerce.struct(CoerceTest::Simple, { "name" => "a", count: "2" })
    assert_equal("a", result.name)
    assert_equal(2, result.count)
  end
end

class CoerceUntypedTest < Minitest::Test
  def test_passes_through_untyped
    assert_equal({ a: 1 }, Fond::Coerce.struct(CoerceTest::Basics, basics(untyped: { a: 1 })).untyped)
  end

  private

  def basics(overrides = {})
    {
      i: 1, f: 1.0, s: "s", sym: :s, d: "2020-01-01", t: "2020-01-01T00:00:00Z",
      dt: "2020-01-01T00:00:00Z", untyped: 1
    }.merge(overrides)
  end
end
