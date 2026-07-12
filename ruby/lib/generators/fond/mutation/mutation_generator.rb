# typed: false
# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"
require_relative "../route_guess"

module Fond
  module Generators
    # rails g fond:mutation Orders::Create
    class MutationGenerator < Rails::Generators::NamedBase
      include RouteGuess

      source_root File.expand_path("templates", __dir__)

      def create_mutation_file
        template "mutation.rb.tt", "app/mutations/#{file_path}_mutation.rb"
      end

      def show_next_steps
        say ""
        say "Add a route:"
        say "  #{fond_http_verb} \"#{fond_route_path}\" => \"#{fond_controller_path}##{fond_action_name}\""
        say ""
        say "Wire the controller:"
        say "  class #{fond_controller_class_name} < ApplicationController"
        say "    mutation #{class_name}Mutation"
        say ""
        say "    def #{fond_action_name}(params)"
        say "      order = Order.create(...)"
        say "      order.persisted? ? redirect_page(paths.ordersShow(id: order.id)) : invalid(order.errors)"
        say "    end"
        say "  end"
      end

      private

      def fond_http_verb
        case file_name
        when "create" then "post"
        when "update", "edit" then "patch"
        when "destroy", "delete" then "delete"
        else "post"
        end
      end
    end
  end
end
