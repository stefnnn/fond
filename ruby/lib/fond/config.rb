# typed: false
# frozen_string_literal: true

module Fond
  class Config
    attr_accessor :output_dir, :version, :pages_import_prefix

    def initialize
      @output_dir = "app/frontend/generated"
      @version = -> { "dev" }
      @pages_import_prefix = "../pages/"
    end
  end

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
    end
  end
end
