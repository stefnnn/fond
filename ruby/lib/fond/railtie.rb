# typed: false
# frozen_string_literal: true

module Fond
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("tasks/fond.rake", __dir__)
    end

    initializer "fond.autogenerate" do |app|
      next unless Rails.env.development? && Fond.config.autogenerate

      app.config.to_prepare do
        Fond::Autogenerate.run
      end

      app.config.after_routes_loaded do
        Fond::Autogenerate.routes_loaded!
        Fond::Autogenerate.run
      end
    end

    initializer "fond.ssr_sidecar", after: :load_config_initializers do
      Fond::Sidecar.start!
    end

    if defined?(Rails::Server)
      Rails::Server.prepend(Module.new do
        def start(*args, &block)
          Fond::Sidecar.mark_server_command!
          super
        end
      end)
    end
  end
end
