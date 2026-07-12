# typed: false
# frozen_string_literal: true

require "rails/generators"

module Fond
  module Generators
    # rails g fond:install [--ssr] [--skip-npm]
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :ssr, type: :boolean, default: false,
                          desc: "Add app/frontend/ssr/ssr.tsx and vite.ssr.config.ts"
      class_option :skip_npm, type: :boolean, default: false,
                               desc: "Skip installing JavaScript dependencies"

      def add_controller_include
        path = "app/controllers/application_controller.rb"
        full = File.join(destination_root, path)
        return unless File.exist?(full)
        return if File.read(full).include?("include Fond::Controller")

        inject_into_file path, after: /class ApplicationController.*\n/ do
          "  include Fond::Controller\n"
        end
      end

      def add_fond_initializer
        template "fond_initializer.rb.tt", "config/initializers/fond.rb"
      end

      def add_dto_inflection
        path = "config/initializers/inflections.rb"
        full = File.join(destination_root, path)
        return unless File.exist?(full)
        return if File.read(full).include?("DTO")

        append_to_file path, <<~RUBY
          ActiveSupport::Inflector.inflections(:en) { |i| i.acronym "DTO" }
        RUBY
      end

      def add_directories
        %w[app/pages app/mutations app/dtos app/frontend/pages app/frontend/components].each do |dir|
          create_file "#{dir}/.keep"
        end
      end

      def add_frontend_entrypoint
        template "application.tsx.tt", "app/frontend/entrypoints/application.tsx"
        template "app.css", "app/frontend/styles/app.css"
      end

      def add_tsconfig
        template "tsconfig.json", "tsconfig.json"
      end

      def add_vite_config
        full = File.join(destination_root, "vite.config.ts")
        if File.exist?(full)
          unless File.read(full).include?("@vitejs/plugin-react")
            say_status :warning,
                        "vite.config.ts exists without @vitejs/plugin-react — add react() to its plugins array.",
                        :yellow
          end
        else
          template "vite.config.ts", "vite.config.ts"
        end
      end

      def add_ssr_files
        return unless options[:ssr]

        template "ssr.tsx.tt", "app/frontend/ssr/ssr.tsx"
        template "vite.ssr.config.ts", "vite.ssr.config.ts"
      end

      def add_layout_tags
        path = "app/views/layouts/application.html.erb"
        full = File.join(destination_root, path)
        return unless File.exist?(full)

        content = File.read(full)
        unless content.include?("vite_javascript_tag")
          inject_into_file path, before: "</head>" do
            "    <%= vite_client_tag %>\n    <%= vite_javascript_tag \"application.tsx\" %>\n"
          end
        end

        return if content.include?("csrf_meta_tags")

        say_status :warning, "#{path} has no csrf_meta_tags — mutations need CSRF tokens.", :yellow
      end

      def add_gems
        full = File.join(destination_root, "Gemfile")
        return unless File.exist?(full)

        gemfile = File.read(full)
        gem "vite_rails" unless gemfile.match?(/["']vite_rails["']/)
        gem "sorbet-runtime" unless gemfile.match?(/["']sorbet-runtime["']/)
      end

      def add_npm_packages
        return if options[:skip_npm]

        template "package.json.tt", "package.json" unless File.exist?(File.join(destination_root, "package.json"))

        deps = %w[fond react react-dom]
        dev_deps = %w[typescript vite vite-plugin-ruby @vitejs/plugin-react @types/react @types/react-dom @types/node]

        inside(".") do
          run "#{add_command} #{deps.join(' ')}"
          run "#{add_dev_command} #{dev_deps.join(' ')}"
        end
      end

      def add_procfile
        template "Procfile.dev.tt", "Procfile.dev" unless File.exist?(procfile_path)
      end

      def add_bin_dev
        return if File.exist?(File.join(destination_root, "bin/dev"))

        copy_file "bin_dev", "bin/dev"
        chmod "bin/dev", 0o755
      end

      def finish
        say ""
        say "fond installed. Next steps:"
        say "  1. bundle install"
        say "  2. bin/rails g fond:page Home  (or any Namespace::Show)"
        say "  3. add a route for it and wire the controller's `page`/`mutation` calls"
        say "  4. bin/dev  (starts vite + rails; codegen runs automatically in development)"
        return if File.exist?(File.join(destination_root, "config/vite.json"))

        say ""
        say "config/vite.json is missing — run `bundle exec vite install` before starting the app."
      end

      private

      def procfile_path
        File.join(destination_root, "Procfile.dev")
      end

      def package_name
        File.basename(destination_root)
      end

      def add_command
        case package_manager
        when :pnpm then "pnpm add"
        when :yarn then "yarn add"
        else "npm install"
        end
      end

      def add_dev_command
        case package_manager
        when :pnpm then "pnpm add -D"
        when :yarn then "yarn add -D"
        else "npm install -D"
        end
      end

      def package_manager
        return @package_manager if defined?(@package_manager)

        dir = destination_root
        loop do
          break @package_manager = :pnpm if File.exist?(File.join(dir, "pnpm-lock.yaml"))
          break @package_manager = :yarn if File.exist?(File.join(dir, "yarn.lock"))
          break @package_manager = :npm if File.exist?(File.join(dir, "package-lock.json"))

          parent = File.dirname(dir)
          break @package_manager = :npm if parent == dir

          dir = parent
        end
      end
    end
  end
end
