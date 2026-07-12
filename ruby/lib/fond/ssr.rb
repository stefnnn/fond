# typed: false
# frozen_string_literal: true

require "net/http"
require "json"

module Fond
  # Client for the SSR sidecar. Failure of any kind degrades to CSR:
  # render returns nil and the caller ships the empty shell instead.
  module Ssr
    class << self
      def render(payload)
        url = Fond.config.ssr_url
        return nil unless url

        uri = URI.join(url, "/render")
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = Fond.config.ssr_timeout
        http.read_timeout = Fond.config.ssr_timeout

        response = http.post(uri.path, payload.to_json, "Content-Type" => "application/json")
        return nil unless response.is_a?(Net::HTTPOK)

        JSON.parse(response.body)["html"]
      rescue StandardError => e
        warn_once(e)
        nil
      end

      private

      # One warning per process per error class, not one per request.
      def warn_once(error)
        @warned ||= {}
        return if @warned[error.class]

        @warned[error.class] = true
        message = "fond: SSR sidecar unavailable, falling back to CSR (#{error.class}: #{error.message})"
        defined?(Rails) ? Rails.logger.warn(message) : warn(message)
      end
    end
  end
end
