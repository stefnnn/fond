# typed: false
# frozen_string_literal: true

require "net/http"
require "json"
require "fileutils"

module Fond
  # Development-only: builds the Vite SSR bundle if stale and spawns/kills the
  # Node sidecar around `bin/rails server`. Never used in production — there,
  # the bundle is built during deploy and `ssr_url`/FOND_SSR_URL points at a
  # separately managed process.
  module Sidecar
    HEALTH_CHECK_TIMEOUT = 2.0
    HEALTH_CHECK_INTERVAL = 0.1

    class << self
      def mark_server_command!
        @server_command = true
      end

      def start!
        return unless @server_command
        return if @started

        @started = true
        return if ENV["FOND_SSR_URL"].to_s != ""
        return unless Fond.config.ssr
        return unless Rails.env.development?

        case port_status
        when :reusable
          Rails.logger.info("fond: reusing existing SSR sidecar at #{url}")
          Fond.config.ssr_url = url
          return
        when :occupied
          Rails.logger.warn("fond: port #{Fond.config.ssr_port} is in use by something other than a Fond SSR sidecar; skipping SSR")
          return
        end

        build_if_stale
        return unless bundle_path.exist?

        spawn_process
        Fond.config.ssr_url = url
        at_exit { stop! }

        if wait_until_healthy
          Rails.logger.info("fond: SSR sidecar running at #{url} (pid #{@pid})")
        else
          Rails.logger.warn("fond: SSR sidecar (pid #{@pid}) did not respond healthy within #{HEALTH_CHECK_TIMEOUT}s, see #{log_path}")
        end
      rescue StandardError => e
        Rails.logger.warn("fond: SSR sidecar failed to start: #{e.class}: #{e.message}")
      end

      def stop!
        return unless @pid

        Process.kill("TERM", @pid)
        Process.wait(@pid)
      rescue StandardError
        nil
      ensure
        @pid = nil
      end

      private

      def url
        "http://127.0.0.1:#{Fond.config.ssr_port}"
      end

      # Returns :free, :reusable (a healthy Fond sidecar already answers on
      # this port — e.g. left running from a previous boot), or :occupied
      # (something else is bound to the port).
      def port_status
        uri = URI.join(url, "/health")
        response = Net::HTTP.start(uri.host, uri.port, open_timeout: 0.5, read_timeout: 0.5) { |http| http.get(uri.path) }
        response.is_a?(Net::HTTPOK) && JSON.parse(response.body)["ok"] == true ? :reusable : :occupied
      rescue Errno::ECONNREFUSED
        :free
      rescue StandardError
        :occupied
      end

      # Polls /health until the just-spawned process answers, or times out —
      # confirms the sidecar actually came up instead of just assuming it did.
      def wait_until_healthy
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + HEALTH_CHECK_TIMEOUT
        loop do
          return true if port_status == :reusable
          return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep HEALTH_CHECK_INTERVAL
        end
      end

      def bundle_path
        Rails.root.join("tmp/ssr/ssr.js")
      end

      def source_dir
        Rails.root.join("app/frontend")
      end

      def build_if_stale
        return unless stale?

        Rails.logger.info("fond: building SSR bundle...")
        FileUtils.mkdir_p(log_path.dirname)
        log = File.open(log_path, "a")
        ok = system(vite_bin.to_s, "build", "--config", "vite.ssr.config.ts",
                     chdir: Rails.root.to_s, out: log, err: log)
        log.close
        Rails.logger.warn("fond: SSR bundle build failed, see #{log_path}") unless ok
      end

      def stale?
        return true unless bundle_path.exist?
        return true unless Dir.exist?(source_dir)

        built_at = bundle_path.mtime
        Dir.glob(source_dir.join("**/*")).any? { |f| File.file?(f) && File.mtime(f) > built_at }
      end

      def vite_bin
        Rails.root.join("node_modules/.bin/vite")
      end

      def spawn_process
        FileUtils.mkdir_p(log_path.dirname)
        @pid = Process.spawn(
          { "FOND_SSR_PORT" => Fond.config.ssr_port.to_s },
          "node", bundle_path.to_s,
          out: log_path.to_s, err: log_path.to_s
        )
      end

      def log_path
        Rails.root.join("log/fond_ssr.log")
      end
    end
  end
end
