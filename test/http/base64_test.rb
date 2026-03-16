# frozen_string_literal: true

require "test_helper"

class HTTPBase64Test < Minitest::Test
  cover "HTTP::Base64*"

  def encoder
    @encoder ||= begin
      klass = Class.new { include HTTP::Base64 }
      klass.new
    end
  end

  def test_encode64_encodes_a_string_using_strict_base64
    assert_equal "aGVsbG8=", encoder.send(:encode64, "hello")
  end

  def test_encode64_produces_output_that_round_trips_back_to_the_original_input
    input = "user:password"

    assert_equal input, encoder.send(:encode64, input).unpack1("m0")
  end

  def test_encode64_encodes_empty_string
    assert_equal "", encoder.send(:encode64, "")
  end
end
