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

      # Drop entries orphaned by code reloading: classes whose constant no
      # longer resolves back to the same object (Zeitwerk unloaded them).
      def prune!
        [@pages ||= [], @mutations ||= []].each do |list|
          list.select! do |klass|
            klass.name && Object.const_defined?(klass.name) && Object.const_get(klass.name).equal?(klass)
          rescue NameError
            false
          end
          list.uniq!
        end
      end
    end
  end
end
