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

  def call_delay(iterations, **options)
    HTTP::Retriable::DelayCalculator.new(options).call(iterations, response)
  end

  def call_retry_header(value, **options)
    response.headers["Retry-After"] = value
    HTTP::Retriable::DelayCalculator.new(options).call(rand(1...100), response)
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

  it "can have a maximum wait time" do
    val1 = call_delay(1, max_delay: 5)

    assert_operator val1, :>=, 0
    assert_operator val1, :<=, 1

    assert_equal 5, call_delay(5, max_delay: 5)
  end

  it "respects Retry-After headers as integer" do
    delay_time = rand(6...2500)
    header_value = delay_time.to_s

    assert_equal delay_time, call_retry_header(header_value)
    assert_equal 5, call_retry_header(header_value, max_delay: 5)
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

  it "does not error on invalid Retry-After header" do
    [
      "This is a string with a number 5 in it",
      "8 Eight is the first digit in this string",
      "This is a string with a #{Time.now.gmtime.to_datetime.rfc2822} timestamp in it"
    ].each do |header_value|
      assert_equal 0, call_retry_header(header_value)
    end
  end
end
