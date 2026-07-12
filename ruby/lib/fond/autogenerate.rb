# typed: false
# frozen_string_literal: true

module Fond
  # Development-mode codegen-on-reload. Wired from the Railtie via
  # config.to_prepare, which fires at boot and after every code reload.
  module Autogenerate
    class << self
      # At boot, to_prepare fires before app routes are drawn (builtin dev
      # routes make the route set look non-empty). after_routes_loaded flips
      # this flag and covers the boot-time generation itself.
      def routes_loaded!
        @routes_loaded = true
      end

      def run
        return unless @routes_loaded

        Fond.config.autogenerate_dirs.each do |dir|
          path = Rails.root.join(dir).to_s
          Rails.autoloaders.main.eager_load_dir(path) if Dir.exist?(path)
        end
        Fond::Registry.prune!

        dir = Rails.root.join(Fond.config.output_dir).to_s
        changed = Fond::Codegen::Generator.new.write(dir)
        changed.each { |f| Rails.logger.info("fond: regenerated #{f}") }
      rescue StandardError => e
        Rails.logger.warn("fond: autogenerate failed: #{e.class}: #{e.message}")
      end
    end
  end
end
