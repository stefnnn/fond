require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.create!(
      customer_name: "Test Customer", customer_email: "t@example.com",
      status: "paid", placed_at: Time.utc(2026, 7, 1, 12, 0), total_cents: 100
    )
    @order.line_items.create!(product_name: "Widget", quantity: 2, unit_price_cents: 50)
    @order.order_events.create!(kind: "note", body: "hi", author: "sys", created_at: Time.utc(2026, 7, 1))
  end

  test "HTML shell embeds page payload" do
    get orders_url
    assert_response :success
    assert_equal "X-Fond", response.headers["Vary"]
    assert_includes response.body, '<div id="fond-root">'
    assert_includes response.body, '<script type="application/json" id="fond-page-data">'

    payload = JSON.parse(response.body[/id="fond-page-data">(.*?)<\/script>/m, 1])
    assert_equal "orders/index", payload["component"]
    assert_equal 1, payload["props"]["totalCount"]
    assert_equal "Test Customer", payload["props"]["orders"].first["customerName"]
  end

  test "fond request returns JSON payload with coerced params" do
    get orders_url(page: "1", status: "paid"), headers: { "X-Fond" => "true" }
    assert_response :success
    assert_equal "application/json", response.media_type

    payload = response.parsed_body
    assert_equal "orders/index", payload["component"]
    assert_equal "/orders?page=1&status=paid", payload["url"]
    assert_equal "dev", payload["version"]
    assert_equal "2026-07-01T12:00:00.000Z", payload["props"]["orders"].first["placedAt"]
  end

  test "show page coerces path params and serializes union activity" do
    get order_url(@order), headers: { "X-Fond" => "true" }
    payload = response.parsed_body
    assert_equal "orders/show", payload["component"]
    assert_equal @order.id, payload["props"]["order"]["id"]
    assert_equal "note", payload["props"]["activity"].first["type"]
  end

  test "invalid params respond 400 with error map" do
    get orders_url(page: "banana"), headers: { "X-Fond" => "true" }
    assert_response :bad_request
    assert_equal({ "error" => "invalid_params", "errors" => { "page" => "must be an integer" } },
                 response.parsed_body)
  end

  test "empty string status filter coerces to nil" do
    get orders_url(status: ""), headers: { "X-Fond" => "true" }
    assert_response :success
    assert_equal 1, response.parsed_body["props"]["totalCount"]
  end

  test "version mismatch responds 409 with location" do
    get orders_url, headers: { "X-Fond" => "true", "X-Fond-Version" => "stale" }
    assert_response :conflict
    assert_equal "/orders", response.headers["X-Fond-Location"]
    assert_empty response.body
  end

  test "matching version is not a conflict" do
    get orders_url, headers: { "X-Fond" => "true", "X-Fond-Version" => "dev" }
    assert_response :success
  end

  test "unknown status enum value responds 400" do
    get orders_url(status: "bogus"), headers: { "X-Fond" => "true" }
    assert_response :bad_request
    assert_match(/must be one of/, response.parsed_body["errors"]["status"])
  end
end
