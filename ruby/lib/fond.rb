# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Fond
end

require "fond/version"
require "fond/error"
require "fond/naming"
require "fond/config"
require "fond/registry"
require "fond/page"
require "fond/mutation"
require "fond/coerce"
require "fond/serialize"
require "fond/controller"
require "fond/routes"
require "fond/ssr"
require "fond/autogenerate"
require "fond/codegen/ts_emitter"
require "fond/codegen/generator"
require "fond/railtie" if defined?(Rails::Railtie)
