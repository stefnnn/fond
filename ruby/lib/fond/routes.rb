# typed: false
# frozen_string_literal: true

module Fond
  # Binds registered pages to Rails routes for codegen.
  module Routes
    Binding = Struct.new(:page, :path, :verb, :required_params, keyword_init: true)

    # Returns one Binding per page, from the first matching GET route.
    # Raises if a concrete page has no route (a page you can't reach is a bug).
    def self.page_bindings(route_set = Rails.application.routes)
      bindings = {}

      route_set.routes.each do |route|
        controller = route.defaults[:controller]
        action = route.defaults[:action]
        next unless controller && action

        klass = "#{controller.camelize}Controller".safe_constantize
        next unless klass.respond_to?(:fond_page_for)

        page = klass.fond_page_for(action)
        next unless page && !bindings.key?(page)
        next unless route.verb.blank? || route.verb.include?("GET")

        bindings[page] = Binding.new(
          page: page,
          path: route.path.spec.to_s.sub("(.:format)", ""),
          verb: "GET",
          required_params: route.required_parts.map(&:to_s) - %w[controller action format]
        )
      end

      missing = Fond::Registry.concrete_pages - bindings.keys
      if missing.any?
        raise Fond::Error, "no GET route found for page(s): #{missing.map(&:name).join(', ')}"
      end

      Fond::Registry.concrete_pages.map { |p| bindings.fetch(p) }
    end
  end
end
