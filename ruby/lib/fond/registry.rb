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

      def reset!
        @pages = []
      end
    end
  end
end
