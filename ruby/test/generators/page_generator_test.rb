# frozen_string_literal: true

require_relative "../test_helper"
require "rails/generators"
require "rails/generators/test_case"
require_relative "../../lib/generators/fond/page/page_generator"

class PageGeneratorTest < Rails::Generators::TestCase
  tests Fond::Generators::PageGenerator
  destination File.expand_path("../../tmp/generators/page", __dir__)

  def setup
    prepare_destination
  end

  def test_nested_page_camel_case
    run_generator ["Orders::Show"]
    assert_nested_output
  end

  def test_nested_page_snake_case_slash
    run_generator ["orders/show"]
    assert_nested_output
  end

  def test_nested_page_colon_syntax
    run_generator ["orders::show"]
    assert_nested_output
  end

  def test_top_level_page
    run_generator ["Home"]

    assert_file "app/pages/home_page.rb" do |content|
      assert_match(/class HomePage < Fond::Page/, content)
      refute_match(/module /, content)
    end
    assert_file "app/frontend/pages/home.tsx" do |content|
      assert_match(/useHome/, content)
      assert_match(/export default function Home\(\)/, content)
      assert_match(%r{\.\./generated/hooks}, content)
    end
  end

  private

  def assert_nested_output
    assert_file "app/pages/orders/show_page.rb" do |content|
      assert_match(/module Orders/, content)
      assert_match(/class ShowPage < Fond::Page/, content)
      assert_match(/class Props < T::Struct/, content)
    end
    assert_file "app/frontend/pages/orders/show.tsx" do |content|
      assert_match(/useOrdersShow/, content)
      assert_match(/export default function OrdersShow\(\)/, content)
      assert_match(%r{\.\./\.\./generated/hooks}, content)
    end
  end
end
