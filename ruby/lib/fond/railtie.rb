# typed: false
# frozen_string_literal: true

module Fond
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("tasks/fond.rake", __dir__)
    end
  end
end
