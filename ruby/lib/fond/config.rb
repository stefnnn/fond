# typed: false
# frozen_string_literal: true

module Fond
  class Config
    attr_accessor :output_dir

    def initialize
      @output_dir = "app/frontend/generated"
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
