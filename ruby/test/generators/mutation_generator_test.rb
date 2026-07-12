# frozen_string_literal: true

require_relative "../test_helper"
require "rails/generators"
require "rails/generators/test_case"
require_relative "../../lib/generators/fond/mutation/mutation_generator"

class MutationGeneratorTest < Rails::Generators::TestCase
  tests Fond::Generators::MutationGenerator
  destination File.expand_path("../../tmp/generators/mutation", __dir__)

  def setup
    prepare_destination
  end

  def test_nested_mutation
    run_generator ["Orders::Create"]

    assert_file "app/mutations/orders/create_mutation.rb" do |content|
      assert_match(/module Orders/, content)
      assert_match(/class CreateMutation < Fond::Mutation/, content)
      assert_match(/class Params < T::Struct/, content)
    end
  end

  def test_name_normalization_matches
    run_generator ["Orders::Create"]
    camel = File.read(File.join(destination_root, "app/mutations/orders/create_mutation.rb"))

    prepare_destination
    run_generator ["orders/create"]
    slash = File.read(File.join(destination_root, "app/mutations/orders/create_mutation.rb"))

    assert_equal camel, slash
  end

  def test_top_level_mutation
    run_generator ["Signup"]

    assert_file "app/mutations/signup_mutation.rb" do |content|
      assert_match(/class SignupMutation < Fond::Mutation/, content)
      refute_match(/module /, content)
    end
  end
end
