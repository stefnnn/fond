# typed: false
# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"
require_relative "../route_guess"

module Fond
  module Generators
    # rails g fond:page Orders::Show
    class PageGenerator < Rails::Generators::NamedBase
      include RouteGuess

      source_root File.expand_path("templates", __dir__)

      def create_page_file
        template "page.rb.tt", "app/pages/#{file_path}_page.rb"
      end

      def create_page_component
        template "page.tsx.tt", "app/frontend/pages/#{file_path}.tsx"
      end

      def show_next_steps
        say ""
        say "Add a route:"
        say "  get \"#{fond_route_path}\" => \"#{fond_controller_path}##{fond_action_name}\""
        say ""
        say "Wire the controller:"
        say "  class #{fond_controller_class_name} < ApplicationController"
        say "    page #{class_name}Page"
        say ""
        say "    def #{fond_action_name}          # takes (params) once you define a Params struct"
        say "      #{class_name}Page::Props.new(name: \"...\")"
        say "    end"
        say "  end"
      end

      private

      def fond_relative_import_path
        "../" * (class_path.length + 1)
      end

      def fond_hooks_import_path
        "#{fond_relative_import_path}generated/hooks"
      end
    end
  end
end
