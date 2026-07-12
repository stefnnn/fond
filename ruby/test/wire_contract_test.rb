# frozen_string_literal: true

require_relative "test_helper"

# The generated TS types use camelCase field names; the wire must match in
# both directions, while user-data hash keys stay untouched.
class WireContractTest < Minitest::Test
  class Inner < T::Struct
    const :unit_price_cents, Integer
  end

  class Outer < T::Struct
    const :total_count, Integer
    const :line_items, T::Array[Inner]
    const :status_counts, T::Hash[String, Integer]
  end

  def test_serialize_camelizes_struct_keys_but_not_hash_keys
    wire = Fond::Serialize.to_wire(
      Outer.new(
        total_count: 2,
        line_items: [Inner.new(unit_price_cents: 100)],
        status_counts: { "in_transit" => 1 }
      )
    )
    assert_equal({ "totalCount" => 2,
                   "lineItems" => [{ "unitPriceCents" => 100 }],
                   "statusCounts" => { "in_transit" => 1 } }, wire)
  end

  def test_coerce_accepts_camel_case_keys_and_reports_camel_paths
    outer = Fond::Coerce.struct(Outer, {
      "totalCount" => "2",
      "lineItems" => [{ "unitPriceCents" => "100" }],
      "statusCounts" => { "in_transit" => "1" }
    })
    assert_equal 2, outer.total_count
    assert_equal 100, outer.line_items.first.unit_price_cents

    err = assert_raises(Fond::Coerce::Error) do
      Fond::Coerce.struct(Outer, { "totalCount" => "x", "lineItems" => [{}], "statusCounts" => {} })
    end
    assert_equal ["lineItems.0.unitPriceCents", "totalCount"], err.errors.keys.sort
  end

  def test_coerce_still_accepts_snake_case_keys
    outer = Fond::Coerce.struct(Outer, {
      "total_count" => 2, "line_items" => [], "status_counts" => {}
    })
    assert_equal 2, outer.total_count
  end
end
