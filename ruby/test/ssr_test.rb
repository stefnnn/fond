# frozen_string_literal: true

require_relative "test_helper"
require "socket"

class SsrTest < Minitest::Test
  def setup
    @original_url = Fond.config.ssr_url
    @original_timeout = Fond.config.ssr_timeout
  end

  def teardown
    Fond.config.ssr_url = @original_url
    Fond.config.ssr_timeout = @original_timeout
  end

  def test_disabled_when_no_url
    Fond.config.ssr_url = nil
    assert_nil Fond::Ssr.render({ component: "x", props: {}, url: "/" })
  end

  def test_renders_html_from_sidecar
    with_stub_sidecar(status: "200 OK", body: { html: "<h1>hi</h1>" }.to_json) do |received|
      html = Fond::Ssr.render({ component: "orders/index", props: { a: 1 }, url: "/orders" })
      assert_equal "<h1>hi</h1>", html
      assert_includes received.first, "POST /render"
      assert_includes received.first, '"component":"orders/index"'
    end
  end

  def test_sidecar_error_falls_back_to_nil
    with_stub_sidecar(status: "500 Internal Server Error", body: { error: "boom" }.to_json) do
      assert_nil Fond::Ssr.render({ component: "x", props: {}, url: "/" })
    end
  end

  def test_unreachable_sidecar_falls_back_to_nil
    Fond.config.ssr_url = "http://127.0.0.1:1"
    Fond.config.ssr_timeout = 0.2
    assert_nil Fond::Ssr.render({ component: "x", props: {}, url: "/" })
  end

  private

  def with_stub_sidecar(status:, body:)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    received = []

    thread = Thread.new do
      client = server.accept
      request = +""
      request << client.readpartial(4096) until request.include?("\r\n\r\n")
      length = request[/Content-Length: (\d+)/i, 1].to_i
      body_read = request.split("\r\n\r\n", 2)[1].to_s
      body_read << client.readpartial(4096) while body_read.bytesize < length
      received << (request + body_read)
      client.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
      client.close
    end

    Fond.config.ssr_url = "http://127.0.0.1:#{port}"
    Fond.config.ssr_timeout = 2.0
    yield received
  ensure
    thread&.kill
    server&.close
  end
end
