# frozen_string_literal: true

require_relative "../test_helper"
require "rails/generators"
require "rails/generators/test_case"
require_relative "../../lib/generators/fond/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Fond::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generators/install", __dir__)

  def setup
    prepare_destination
    write_fixtures
  end

  def test_creates_initializer_entrypoint_tsconfig_procfile_and_bin_dev
    run_generator ["--skip-npm"]

    assert_file "config/initializers/fond.rb" do |content|
      assert_match(/Fond\.configure do \|config\|/, content)
      assert_match(/# config\.shared_props_class_name/, content)
    end
    assert_file "app/frontend/entrypoints/application.tsx" do |content|
      assert_match(/createFondApp/, content)
    end
    assert_file "tsconfig.json"
    assert_file "Procfile.dev"
    assert_file "bin/dev"
    assert File.executable?(File.join(destination_root, "bin/dev"))
  end

  def test_injects_controller_include_and_layout_tags_and_dto_inflection
    run_generator ["--skip-npm"]

    assert_file "app/controllers/application_controller.rb" do |content|
      assert_match(/include Fond::Controller/, content)
    end
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_match(/vite_client_tag/, content)
      assert_match(/vite_javascript_tag "application\.tsx"/, content)
    end
    assert_file "config/initializers/inflections.rb" do |content|
      assert_match(/acronym "DTO"/, content)
    end
  end

  def test_idempotent_when_run_twice
    run_generator ["--skip-npm"]
    run_generator ["--skip-npm"]

    controller = File.read(File.join(destination_root, "app/controllers/application_controller.rb"))
    assert_equal 1, controller.scan("include Fond::Controller").size

    layout = File.read(File.join(destination_root, "app/views/layouts/application.html.erb"))
    assert_equal 1, layout.scan("vite_javascript_tag").size

    inflections = File.read(File.join(destination_root, "config/initializers/inflections.rb"))
    assert_equal 1, inflections.scan("DTO").size
  end

  def test_ssr_adds_ssr_files
    run_generator ["--skip-npm", "--ssr"]

    assert_file "app/frontend/ssr/ssr.tsx" do |content|
      assert_match(/createSsrServer/, content)
    end
    assert_file "vite.ssr.config.ts"
    assert_file "config/initializers/fond.rb" do |content|
      assert_match(/config\.ssr = true/, content)
    end
  end

  def test_creates_keep_directories
    run_generator ["--skip-npm"]

    %w[app/pages app/mutations app/dtos app/frontend/pages app/frontend/components].each do |dir|
      assert_file "#{dir}/.keep"
    end
  end

  private

  def write_fixtures
    write "app/controllers/application_controller.rb", <<~RUBY
      class ApplicationController < ActionController::Base
      end
    RUBY

    write "app/views/layouts/application.html.erb", <<~ERB
      <!DOCTYPE html>
      <html>
        <head>
          <title>Test</title>
          <%= csrf_meta_tags %>
        </head>
        <body>
          <%= yield %>
        </body>
      </html>
    ERB

    write "config/initializers/inflections.rb", <<~RUBY
      ActiveSupport::Inflector.inflections(:en) do |inflect|
      end
    RUBY

    write "Gemfile", <<~RUBY
      source "https://rubygems.org"
      gem "rails"
    RUBY
  end

  def write(relative_path, content)
    full = File.join(destination_root, relative_path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end
end
