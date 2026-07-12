# typed: false
# frozen_string_literal: true

module Fond
  module Naming
    def self.camelize(name)
      parts = name.to_s.split("_")
      parts[0] + parts[1..].map { |p| p[0].upcase + p[1..] }.join
    end
  end
end
