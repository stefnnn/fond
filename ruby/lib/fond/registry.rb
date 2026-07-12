# typed: false
# frozen_string_literal: true

module Fond
  module Registry
    class << self
      def register(page_class)
        pages << page_class
      end

      def pages
        @pages ||= []
      end

      # Anonymous classes and abstract intermediates (no Props) are skipped.
      def concrete_pages
        pages.select { |p| p.name && p.const_defined?(:Props, false) }.sort_by(&:name)
      end

      def register_mutation(mutation_class)
        mutations << mutation_class
      end

      def mutations
        @mutations ||= []
      end

      def concrete_mutations
        mutations.select { |m| m.name && m.const_defined?(:Params, false) }.sort_by(&:name)
      end

      def reset!
        @pages = []
        @mutations = []
      end
    end
  end
end
