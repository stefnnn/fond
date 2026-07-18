# frozen_string_literal: true

require_relative "test_helper"
require "socket"
require "tmpdir"
require "fileutils"
require "logger"

module Rails
  class Env < String
    def development?
      self == "development"
    end
  end

  class << self
    attr_accessor :root, :logger

    def env
      @env ||= Env.new("development")
    end
  end
end

Rails.logger = Logger.new(IO::NULL)

class SidecarTest < Minitest::Test
  def setup
    @original_ssr = Fond.config.ssr
    @original_ssr_url = Fond.config.ssr_url
    @original_ssr_port = Fond.config.ssr_port
    @original_env_url = ENV.delete("FOND_SSR_URL")
    @original_root = Rails.root

    reset_sidecar_state!
  end

  def teardown
    Fond::Sidecar.stop!
    Fond.config.ssr = @original_ssr
    Fond.config.ssr_url = @original_ssr_url
    Fond.config.ssr_port = @original_ssr_port
    ENV["FOND_SSR_URL"] = @original_env_url if @original_env_url
    Rails.root = @original_root
    reset_sidecar_state!
  end

  def test_noop_when_not_a_server_command
    Fond.config.ssr = true
    Fond::Sidecar.start!

    assert_nil Fond.config.ssr_url
  end

  def test_noop_when_ssr_disabled
    Fond::Sidecar.mark_server_command!
    Fond.config.ssr = false
    Fond::Sidecar.start!

    assert_nil Fond.config.ssr_url
  end

  def test_noop_when_fond_ssr_url_env_present
    ENV["FOND_SSR_URL"] = "http://example.test"
    Fond::Sidecar.mark_server_command!
    Fond.config.ssr = true
    Fond::Sidecar.start!

    assert_nil Fond.config.ssr_url
  end

  def test_reuses_healthy_sidecar_already_on_the_port
    with_stub_health_server(status: "200 OK", body: { ok: true }.to_json) do |port|
      Fond.config.ssr_port = port
      Fond.config.ssr = true
      Fond::Sidecar.mark_server_command!

      Fond::Sidecar.start!

      assert_equal "http://127.0.0.1:#{port}", Fond.config.ssr_url
      assert_nil Fond::Sidecar.instance_variable_get(:@pid)
    end
  end

  def test_skips_when_port_occupied_by_something_else
    with_stub_health_server(status: "404 Not Found", body: "") do |port|
      Fond.config.ssr_port = port
      Fond.config.ssr = true
      Fond::Sidecar.mark_server_command!

      Fond::Sidecar.start!

      assert_nil Fond.config.ssr_url
      assert_nil Fond::Sidecar.instance_variable_get(:@pid)
    end
  end

  def test_builds_stale_bundle_and_spawns_sidecar
    Dir.mktmpdir do |root|
      Rails.root = Pathname.new(root)
      write_fake_vite(root)

      port = free_port
      Fond.config.ssr_port = port
      Fond.config.ssr = true
      Fond::Sidecar.mark_server_command!

      Fond::Sidecar.start!

      assert wait_until { port_open?(port) }, "expected the sidecar to start listening"
      assert_equal "http://127.0.0.1:#{port}", Fond.config.ssr_url
      assert File.exist?(File.join(root, "tmp/ssr/ssr.js"))

      pid = Fond::Sidecar.instance_variable_get(:@pid)
      refute_nil pid

      Fond::Sidecar.stop!
      assert wait_until { !process_alive?(pid) }, "expected the sidecar process to be terminated"
    end
  end

  private

  def reset_sidecar_state!
    Fond::Sidecar.instance_variable_set(:@server_command, nil)
    Fond::Sidecar.instance_variable_set(:@started, nil)
    Fond::Sidecar.instance_variable_set(:@pid, nil)
  end

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end

  def port_open?(port)
    TCPSocket.new("127.0.0.1", port).close
    true
  rescue Errno::ECONNREFUSED
    false
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def wait_until(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return true if yield

      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def write_fake_vite(root)
    bin_dir = File.join(root, "node_modules/.bin")
    FileUtils.mkdir_p(bin_dir)
    fake_vite = File.join(bin_dir, "vite")
    File.write(fake_vite, <<~SH)
      #!/bin/sh
      mkdir -p tmp/ssr
      cat > tmp/ssr/ssr.js <<'JS'
      const http = require("http");
      http.createServer((req, res) => {
        if (req.url === "/health") {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ ok: true }));
        } else {
          res.writeHead(404);
          res.end();
        }
      }).listen(Number(process.env.FOND_SSR_PORT), "127.0.0.1");
      JS
    SH
    FileUtils.chmod(0o755, fake_vite)
  end

  def with_stub_health_server(status:, body:)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]

    thread = Thread.new do
      client = server.accept
      request = +""
      request << client.readpartial(4096) until request.include?("\r\n\r\n")
      client.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
      client.close
    end

    yield port
  ensure
    thread&.kill
    server&.close
  end
end
