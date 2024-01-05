# frozen_string_literal: true

RSpec.describe HTTP::Retriable::DelayCalculator do
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
    described_class.new(options).call(iterations, response)
  end

  def call_retry_header(value, **options)
    response.headers["Retry-After"] = value
    described_class.new(options).call(rand(1...100), response)
  end

  it "prevents negative sleep time" do
    expect(call_delay(20, delay: -20)).to eq 0
  end

  it "backs off exponentially" do
    expect(call_delay(1)).to be_between 0, 1
    expect(call_delay(2)).to be_between 1, 2
    expect(call_delay(3)).to be_between 3, 4
    expect(call_delay(4)).to be_between 7, 8
    expect(call_delay(5)).to be_between 15, 16
  end

  it "can have a maximum wait time" do
    expect(call_delay(1, max_delay: 5)).to be_between 0, 1
    expect(call_delay(5, max_delay: 5)).to eq 5
  end

  it "respects Retry-After headers as integer" do
    delay_time = rand(6...2500)
    header_value = delay_time.to_s
    expect(call_retry_header(header_value)).to eq delay_time
    expect(call_retry_header(header_value, max_delay: 5)).to eq 5
  end

  it "respects Retry-After headers as rfc2822 timestamp" do
    delay_time = rand(6...2500)
    header_value = (Time.now.gmtime + delay_time).to_datetime.rfc2822.sub("+0000", "GMT")
    expect(call_retry_header(header_value)).to be_within(1).of(delay_time)
    expect(call_retry_header(header_value, max_delay: 5)).to eq 5
  end

  it "respects Retry-After headers as rfc2822 timestamp in the past" do
    delay_time = rand(6...2500)
    header_value = (Time.now.gmtime - delay_time).to_datetime.rfc2822.sub("+0000", "GMT")
    expect(call_retry_header(header_value)).to eq 0
  end

  it "does not error on invalid Retry-After header" do
    [ # invalid strings
      "This is a string with a number 5 in it",
      "8 Eight is the first digit in this string",
      "This is a string with a #{Time.now.gmtime.to_datetime.rfc2822} timestamp in it"
    ].each do |header_value|
      expect(call_retry_header(header_value)).to eq 0
    end
  end
end
