# typed: false
# frozen_string_literal: true

module Fond
  # Binds registered pages and mutations to Rails routes for codegen.
  module Routes
    Binding = Struct.new(:page, :path, :verb, :required_params, keyword_init: true)

    # Returns one Binding per page, from the first matching GET route.
    # Raises if a concrete page has no route (a page you can't reach is a bug).
    def self.page_bindings(route_set = Rails.application.routes)
      bind(
        route_set,
        Fond::Registry.concrete_pages,
        lookup: :fond_page_for,
        verbs: ["GET"]
      )
    end

    def self.mutation_bindings(route_set = Rails.application.routes)
      bind(
        route_set,
        Fond::Registry.concrete_mutations,
        lookup: :fond_mutation_for,
        verbs: %w[POST PATCH PUT DELETE]
      )
    end

    def self.bind(route_set, targets, lookup:, verbs:)
      bindings = {}

      route_set.routes.each do |route|
        controller = route.defaults[:controller]
        action = route.defaults[:action]
        next unless controller && action

        klass = "#{controller.camelize}Controller".safe_constantize
        next unless klass.respond_to?(lookup)

        target = klass.public_send(lookup, action)
        next unless target && !bindings.key?(target)

        verb = verbs.find { |v| route.verb.blank? || route.verb.include?(v) }
        next unless verb

        bindings[target] = Binding.new(
          page: target,
          path: route.path.spec.to_s.sub("(.:format)", ""),
          verb: verb,
          required_params: route.required_parts.map(&:to_s) - %w[controller action format]
        )
      end

      missing = targets - bindings.keys
      if missing.any?
        raise Fond::Error, "no route found for: #{missing.map(&:name).join(', ')}"
      end

      targets.map { |t| bindings.fetch(t) }
    end
    private_class_method :bind
  end
end
