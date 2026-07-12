require "test_helper"

class MutationsTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.create!(
      customer_name: "Test", customer_email: "t@example.com",
      status: "pending", placed_at: Time.current
    )
  end

  test "create with nested line items redirects" do
    post orders_url, as: :json, headers: { "X-Fond" => "true" }, params: {
      customerName: "Nora", customerEmail: "nora@example.com", notes: nil,
      lineItems: [ { productName: "Aeropress", quantity: "2", unitPriceCents: "4200" } ]
    }
    assert_response :success

    order = Order.order(:id).last
    assert_equal({ "redirect" => "/orders/#{order.id}" }, response.parsed_body)
    assert_equal "Nora", order.customer_name
    assert_equal 8400, order.total_cents
    assert_equal 1, order.line_items.count
  end

  test "create with model validation failure returns 422 canonical errors" do
    post orders_url, as: :json, headers: { "X-Fond" => "true" }, params: {
      customerName: "", customerEmail: "not-an-email",
      lineItems: [ { productName: "X", quantity: 1, unitPriceCents: 1 } ]
    }
    assert_response :unprocessable_content

    errors = response.parsed_body["errors"]
    assert_equal [], errors["base"]
    assert_includes errors["fields"]["customerName"], "Customer name can't be blank"
    assert_includes errors["fields"]["customerEmail"], "Customer email is not a valid email"
  end

  test "create with base error returns 422" do
    post orders_url, as: :json, headers: { "X-Fond" => "true" }, params: {
      customerName: "A", customerEmail: "a@example.com", lineItems: []
    }
    assert_response :unprocessable_content
    assert_equal [ "Add at least one line item" ], response.parsed_body["errors"]["base"]
  end

  test "create with coercion failure returns 400 with dotted camel paths" do
    post orders_url, as: :json, headers: { "X-Fond" => "true" }, params: {
      customerName: "A", customerEmail: "a@example.com",
      lineItems: [ { productName: "X", quantity: "lots", unitPriceCents: 1 } ]
    }
    assert_response :bad_request
    assert_equal({ "lineItems.0.quantity" => "must be an integer" }, response.parsed_body["errors"])
  end

  test "update_status merges path param into typed params" do
    patch update_status_order_url(@order), as: :json,
      headers: { "X-Fond" => "true" }, params: { status: "paid" }
    assert_equal({ "redirect" => "/orders/#{@order.id}" }, response.parsed_body)
    assert_equal "paid", @order.reload.status
    assert_equal "status_change", @order.order_events.last.kind
  end

  test "update_status to same status returns base error" do
    patch update_status_order_url(@order), as: :json,
      headers: { "X-Fond" => "true" }, params: { status: "pending" }
    assert_response :unprocessable_content
    assert_equal [ "Order is already pending" ], response.parsed_body["errors"]["base"]
  end

  test "destroy redirects to index" do
    delete order_url(@order), as: :json, headers: { "X-Fond" => "true" }
    assert_equal({ "redirect" => "/orders" }, response.parsed_body)
    assert_nil Order.find_by(id: @order.id)
  end

  test "mutations are exempt from version check" do
    post add_note_order_url(@order), as: :json,
      headers: { "X-Fond" => "true", "X-Fond-Version" => "stale" }, params: { body: "hello" }
    assert_response :success
    assert_equal "hello", @order.order_events.last.body
  end
end
