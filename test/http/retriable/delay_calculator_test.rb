# frozen_string_literal: true

require "test_helper"

class HTTPRetriableDelayCalculatorTest < Minitest::Test
  cover "HTTP::Retriable::DelayCalculator*"

  def response
    @response ||= HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      request: HTTP::Request.new(verb: :get, uri: "http://example.com")
    )
  end

  def call_delay(iterations, response: self.response, **)
    HTTP::Retriable::DelayCalculator.new(**).call(iterations, response)
  end

  def call_retry_header(value, **)
    response.headers["Retry-After"] = value
    HTTP::Retriable::DelayCalculator.new(**).call(rand(1...100), response)
  end

  def test_prevents_negative_sleep_time
    assert_equal 0, call_delay(20, delay: -20)
  end

  def test_backs_off_exponentially
    val1 = call_delay(1)

    assert_operator val1, :>=, 0
    assert_operator val1, :<=, 1

    val2 = call_delay(2)

    assert_operator val2, :>=, 1
    assert_operator val2, :<=, 2

    val3 = call_delay(3)

    assert_operator val3, :>=, 3
    assert_operator val3, :<=, 4

    val4 = call_delay(4)

    assert_operator val4, :>=, 7
    assert_operator val4, :<=, 8

    val5 = call_delay(5)

    assert_operator val5, :>=, 15
    assert_operator val5, :<=, 16
  end

  def test_includes_jitter_in_exponential_backoff
    results = Array.new(10) { call_delay(3) }

    assert results.any? { |v| v > 3 }, "expected at least one value with jitter above base delay of 3"
  end

  def test_always_returns_a_float
    assert_instance_of Float, call_delay(1, delay: 2)
    assert_instance_of Float, call_delay(1)
  end

  def test_can_have_a_maximum_wait_time
    val1 = call_delay(1, max_delay: 5)

    assert_operator val1, :>=, 0
    assert_operator val1, :<=, 1
    assert_equal 5, call_delay(5, max_delay: 5)
  end

  def test_caps_delay_at_max_delay
    assert_in_delta(5.0, call_delay(10, max_delay: 5, delay: 100))
  end

  def test_converts_max_delay_to_float
    calc = HTTP::Retriable::DelayCalculator.new(max_delay: 10)

    assert_instance_of Float, calc.instance_variable_get(:@max_delay)
  end

  # -- with a delay proc --

  def test_with_delay_proc_calls_the_proc_with_iteration_number
    received_iteration = nil
    delay_proc = proc do |iteration|
      received_iteration = iteration
      iteration * 2
    end

    result = call_delay(3, delay: delay_proc)

    assert_equal 3, received_iteration
    assert_in_delta(6.0, result)
  end

  def test_with_delay_proc_uses_proc_return_value_as_delay
    delay_proc = ->(i) { i * 10 }

    assert_in_delta(10.0, call_delay(1, delay: delay_proc))
    assert_in_delta(50.0, call_delay(5, delay: delay_proc))
  end

  def test_with_delay_proc_clamps_return_value_to_max_delay
    delay_proc = ->(_i) { 100 }

    assert_in_delta(5.0, call_delay(1, delay: delay_proc, max_delay: 5))
  end

  # -- with a nil response --

  def test_with_nil_response_falls_back_to_iteration_based_delay
    result = call_delay(1, response: nil)

    assert_operator result, :>=, 0
    assert_operator result, :<=, 1
  end

  def test_with_nil_response_uses_fixed_delay_when_provided
    assert_in_delta(2.0, call_delay(1, delay: 2, response: nil))
  end

  # -- Retry-After headers --

  def test_respects_retry_after_headers_as_integer
    delay_time = rand(6...2500)
    header_value = delay_time.to_s

    assert_equal delay_time, call_retry_header(header_value)
    assert_equal 5, call_retry_header(header_value, max_delay: 5)
  end

  def test_respects_retry_after_headers_as_integer_with_whitespace
    assert_equal 42, call_retry_header("  42  ")
    assert_equal 10, call_retry_header("10\t")
  end

  def test_respects_retry_after_headers_as_rfc2822_timestamp
    delay_time = rand(6...2500)
    header_value = (Time.now.gmtime + delay_time).to_datetime.rfc2822.sub("+0000", "GMT")

    assert_in_delta delay_time, call_retry_header(header_value), 1
    assert_equal 5, call_retry_header(header_value, max_delay: 5)
  end

  def test_respects_retry_after_headers_as_rfc2822_timestamp_in_the_past
    delay_time = rand(6...2500)
    header_value = (Time.now.gmtime - delay_time).to_datetime.rfc2822.sub("+0000", "GMT")

    assert_equal 0, call_retry_header(header_value)
  end

  def test_handles_non_string_retry_after_header_values
    response.headers["Retry-After"] = 42
    calc = HTTP::Retriable::DelayCalculator.new
    result = calc.call(1, response)

    assert_in_delta(42.0, result)
  end

  def test_does_not_error_on_invalid_retry_after_header
    [
      "This is a string with a number 5 in it",
      "8 Eight is the first digit in this string",
      "This is a string with a #{Time.now.gmtime.to_datetime.rfc2822} timestamp in it"
    ].each do |header_value|
      assert_equal 0, call_retry_header(header_value)
    end
  end

  def test_returns_zero_for_invalid_retry_after_header
    calc = HTTP::Retriable::DelayCalculator.new
    result = calc.delay_from_retry_header("invalid-value")

    assert_equal 0, result
  end

  def test_coerces_non_string_retry_after_values_via_to_s
    calc = HTTP::Retriable::DelayCalculator.new

    assert_in_delta(42.0, calc.delay_from_retry_header(42))
  end

  def test_parses_integer_retry_after_with_embedded_newline_via_to_i
    calc = HTTP::Retriable::DelayCalculator.new

    assert_in_delta(5.0, calc.delay_from_retry_header("5\nfoo"))
  end
end
