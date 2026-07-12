# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Fond
end

require "fond/version"
require "fond/railtie" if defined?(Rails::Railtie)
