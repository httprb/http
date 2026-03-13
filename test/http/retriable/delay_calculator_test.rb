# frozen_string_literal: true

require "test_helper"

describe HTTP::Retriable::DelayCalculator do
  cover "HTTP::Retriable::DelayCalculator*"
  let(:response) do
    HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      request: HTTP::Request.new(verb: :get, uri: "http://example.com")
    )
  end

  def call_delay(iterations, response: self.response, **options)
    HTTP::Retriable::DelayCalculator.new(**options).call(iterations, response)
  end

  def call_retry_header(value, **options)
    response.headers["Retry-After"] = value
    HTTP::Retriable::DelayCalculator.new(**options).call(rand(1...100), response)
  end

  it "prevents negative sleep time" do
    assert_equal 0, call_delay(20, delay: -20)
  end

  it "backs off exponentially" do
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

  it "includes jitter in exponential backoff" do
    # The base delay for iteration 3 is (2^2) - 1 = 3
    # With jitter (rand 0..1), result must be strictly greater than the base
    results = Array.new(10) { call_delay(3) }

    assert results.any? { |v| v > 3 }, "expected at least one value with jitter above base delay of 3"
  end

  it "always returns a Float" do
    assert_instance_of Float, call_delay(1, delay: 2)
    assert_instance_of Float, call_delay(1)
  end

  it "can have a maximum wait time" do
    val1 = call_delay(1, max_delay: 5)

    assert_operator val1, :>=, 0
    assert_operator val1, :<=, 1

    assert_equal 5, call_delay(5, max_delay: 5)
  end

  it "caps delay at max_delay" do
    assert_in_delta(5.0, call_delay(10, max_delay: 5, delay: 100))
  end

  it "converts max_delay to Float" do
    calc = HTTP::Retriable::DelayCalculator.new(max_delay: 10)

    assert_instance_of Float, calc.instance_variable_get(:@max_delay)
  end

  context "with a delay proc" do
    it "calls the proc with the iteration number" do
      received_iteration = nil
      delay_proc = proc do |iteration|
        received_iteration = iteration
        iteration * 2
      end

      result = call_delay(3, delay: delay_proc)

      assert_equal 3, received_iteration
      assert_in_delta(6.0, result)
    end

    it "uses the proc return value as the delay" do
      delay_proc = ->(i) { i * 10 }

      assert_in_delta(10.0, call_delay(1, delay: delay_proc))
      assert_in_delta(50.0, call_delay(5, delay: delay_proc))
    end

    it "clamps the proc return value to max_delay" do
      delay_proc = ->(_i) { 100 }

      assert_in_delta(5.0, call_delay(1, delay: delay_proc, max_delay: 5))
    end
  end

  context "with a nil response" do
    it "falls back to iteration-based delay" do
      result = call_delay(1, response: nil)

      assert_operator result, :>=, 0
      assert_operator result, :<=, 1
    end

    it "uses fixed delay when provided" do
      assert_in_delta(2.0, call_delay(1, delay: 2, response: nil))
    end
  end

  it "respects Retry-After headers as integer" do
    delay_time = rand(6...2500)
    header_value = delay_time.to_s

    assert_equal delay_time, call_retry_header(header_value)
    assert_equal 5, call_retry_header(header_value, max_delay: 5)
  end

  it "respects Retry-After headers as integer with whitespace" do
    assert_equal 42, call_retry_header("  42  ")
    assert_equal 10, call_retry_header("10\t")
  end

  it "respects Retry-After headers as rfc2822 timestamp" do
    delay_time = rand(6...2500)
    header_value = (Time.now.gmtime + delay_time).to_datetime.rfc2822.sub("+0000", "GMT")

    assert_in_delta delay_time, call_retry_header(header_value), 1
    assert_equal 5, call_retry_header(header_value, max_delay: 5)
  end

  it "respects Retry-After headers as rfc2822 timestamp in the past" do
    delay_time = rand(6...2500)
    header_value = (Time.now.gmtime - delay_time).to_datetime.rfc2822.sub("+0000", "GMT")

    assert_equal 0, call_retry_header(header_value)
  end

  it "handles non-string Retry-After header values" do
    response.headers["Retry-After"] = 42
    calc = HTTP::Retriable::DelayCalculator.new
    result = calc.call(1, response)

    assert_in_delta(42.0, result)
  end

  it "does not error on invalid Retry-After header" do
    [
      "This is a string with a number 5 in it",
      "8 Eight is the first digit in this string",
      "This is a string with a #{Time.now.gmtime.to_datetime.rfc2822} timestamp in it"
    ].each do |header_value|
      assert_equal 0, call_retry_header(header_value)
    end
  end

  it "returns zero for invalid Retry-After header" do
    calc = HTTP::Retriable::DelayCalculator.new
    result = calc.delay_from_retry_header("invalid-value")

    assert_equal 0, result
  end

  it "coerces non-string Retry-After values via to_s" do
    calc = HTTP::Retriable::DelayCalculator.new

    assert_in_delta(42.0, calc.delay_from_retry_header(42))
  end

  it "parses integer Retry-After with embedded newline via to_i" do
    calc = HTTP::Retriable::DelayCalculator.new

    assert_in_delta(5.0, calc.delay_from_retry_header("5\nfoo"))
  end
end
