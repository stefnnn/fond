# frozen_string_literal: true

require_relative "test_helper"

class MutationTest < Minitest::Test
  def test_redirect_accepts_relative_path
    redirect = Fond::Redirect.new("/orders/5")
    assert_equal("/orders/5", redirect.url)
  end

  def test_redirect_rejects_absolute_url
    assert_raises(ArgumentError) { Fond::Redirect.new("https://evil.example/phish") }
  end

  def test_redirect_rejects_protocol_relative_url
    assert_raises(ArgumentError) { Fond::Redirect.new("//evil.example/phish") }
  end

  def test_redirect_rejects_non_string
    assert_raises(ArgumentError) { Fond::Redirect.new(nil) }
  end
end
