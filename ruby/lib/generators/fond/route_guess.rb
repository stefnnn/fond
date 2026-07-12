# typed: false
# frozen_string_literal: true

module Fond
  module Generators
    # Shared route/controller guessing for the page and mutation generators.
    # Both are Rails::Generators::NamedBase, so class_path/file_name are set.
    module RouteGuess
      private

      def fond_component_name
        (class_path.map(&:camelize) + [file_name.camelize]).join
      end

      def fond_hook_name
        "use#{fond_component_name}"
      end

      def fond_route_path
        (class_path + [file_name]).join("/")
      end

      def fond_controller_path
        class_path.any? ? class_path.join("/") : file_name.pluralize
      end

      def fond_controller_class_name
        "#{fond_controller_path.camelize}Controller"
      end

      def fond_action_name
        class_path.any? ? file_name : "index"
      end
    end
  end
end
