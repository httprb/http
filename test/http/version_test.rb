# frozen_string_literal: true

require "test_helper"

class HTTPVersionTest < Minitest::Test
  cover "HTTP::VERSION*"

  def test_is_a_string
    assert_kind_of String, HTTP::VERSION
  end

  def test_follows_semantic_versioning
    assert_match(/\A\d+\.\d+\.\d+/, HTTP::VERSION)
  end
end
