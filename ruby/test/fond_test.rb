# frozen_string_literal: true

require_relative "test_helper"

class FondTest < Minitest::Test
  def test_version
    assert_match(/\A\d+\.\d+\.\d+\z/, Fond::VERSION)
  end
end
