# frozen_string_literal: true

require "test_helper"

class HTTPFeaturesInstrumentationTest < Minitest::Test
  cover "HTTP::Features::Instrumentation*"

  def instrumenter_class
    @instrumenter_class ||= Class.new(HTTP::Features::Instrumentation::NullInstrumenter) do
      attr_reader :events

      def initialize
        super
        @events = []
      end

      def start(name, payload)
        events << { type: :start, name: name, payload: payload.dup }
      end

      def finish(name, payload)
        events << { type: :finish, name: name, payload: payload.dup }
      end
    end
  end

  def instrumenter
    @instrumenter ||= instrumenter_class.new
  end

  def feature
    @feature ||= HTTP::Features::Instrumentation.new(instrumenter: instrumenter)
  end

  def request
    @request ||= HTTP::Request.new(
      verb:    :post,
      uri:     "https://example.com/",
      headers: { accept: "application/json" },
      body:    '{"hello": "world!"}'
    )
  end

  def response
    @response ||= HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "application/json" },
      body:    '{"success": true}',
      request: request
    )
  end

  # -- initialization --

  def test_initialization_uses_null_instrumenter_when_no_instrumenter_provided
    f = HTTP::Features::Instrumentation.new

    assert_instance_of HTTP::Features::Instrumentation::NullInstrumenter, f.instrumenter
  end

  def test_initialization_sets_name_to_request_http_by_default
    f = HTTP::Features::Instrumentation.new

    assert_equal "request.http", f.name
  end

  def test_initialization_sets_error_name_to_error_http_by_default
    f = HTTP::Features::Instrumentation.new

    assert_equal "error.http", f.error_name
  end

  def test_initialization_uses_a_custom_namespace
    f = HTTP::Features::Instrumentation.new(namespace: "my_app")

    assert_equal "request.my_app", f.name
    assert_equal "error.my_app", f.error_name
  end

  # -- around_request --

  def test_around_request_emits_start_event_with_correct_name
    feature.around_request(request) { response }
    first_event = instrumenter.events.first

    assert_equal "start_request.http", first_event[:name]
  end

  def test_around_request_emits_start_event_with_request_payload
    feature.around_request(request) { response }
    first_event = instrumenter.events.first

    assert_equal({ request: request }, first_event[:payload])
  end

  def test_around_request_finishes_instrumentation_span_with_response
    feature.around_request(request) { response }
    last_finish = instrumenter.events.reverse.find { |e| e[:type] == :finish }

    assert_equal({ request: request, response: response }, last_finish[:payload])
  end

  def test_around_request_emits_main_event_with_correct_name
    feature.around_request(request) { response }
    main_finishes = instrumenter.events.select { |e| e[:type] == :finish && e[:name] == "request.http" }

    assert_equal 1, main_finishes.length
  end

  def test_around_request_returns_the_response_from_the_block
    result = feature.around_request(request) { response }

    assert_same response, result
  end

  def test_around_request_passes_the_request_to_the_block
    received = nil
    feature.around_request(request) do |req|
      received = req
      response
    end

    assert_same request, received
  end

  def test_around_request_finishes_span_even_when_block_raises
    assert_raises(RuntimeError) do
      feature.around_request(request) { raise "boom" }
    end
    last_finish = instrumenter.events.reverse.find { |e| e[:type] == :finish }

    assert_equal({ request: request }, last_finish[:payload])
  end

  # -- on_error --

  def test_on_error_instruments_the_error_with_correct_event_name
    error = HTTP::TimeoutError.new
    feature.on_error(request, error)
    finish_event = instrumenter.events.find { |e| e[:type] == :finish }

    assert_equal "error.http", finish_event[:name]
  end

  def test_on_error_logs_the_error_payload
    error = HTTP::TimeoutError.new
    feature.on_error(request, error)
    finish_event = instrumenter.events.find { |e| e[:type] == :finish }

    assert_equal({ request: request, error: error }, finish_event[:payload])
  end

  # -- NullInstrumenter --

  def test_null_instrumenter_start_is_callable
    null_instrumenter = HTTP::Features::Instrumentation::NullInstrumenter.new
    null_instrumenter.start("test", {})
  end

  def test_null_instrumenter_finish_is_callable
    null_instrumenter = HTTP::Features::Instrumentation::NullInstrumenter.new
    null_instrumenter.finish("test", {})
  end

  def test_null_instrumenter_instrument_is_callable_without_a_block
    null_instrumenter = HTTP::Features::Instrumentation::NullInstrumenter.new
    null_instrumenter.instrument("test")
  end

  def test_null_instrumenter_instrument_yields_the_payload_to_the_block
    null_instrumenter = HTTP::Features::Instrumentation::NullInstrumenter.new
    received = nil
    null_instrumenter.instrument("test", { key: "value" }) { |payload| received = payload }

    assert_equal({ key: "value" }, received)
  end

  def test_null_instrumenter_instrument_defaults_payload_to_empty_hash
    null_instrumenter = HTTP::Features::Instrumentation::NullInstrumenter.new
    received = nil
    null_instrumenter.instrument("test") { |payload| received = payload }

    assert_equal({}, received)
  end

  def test_null_instrumenter_instrument_passes_name_to_start_and_finish
    names = []
    inst = HTTP::Features::Instrumentation::NullInstrumenter.new
    inst.define_singleton_method(:start) { |name, _payload| names << [:start, name] }
    inst.define_singleton_method(:finish) { |name, _payload| names << [:finish, name] }
    inst.instrument("test.event") { nil }

    assert_equal [[:start, "test.event"], [:finish, "test.event"]], names
  end

  def test_null_instrumenter_instrument_calls_finish_even_when_block_raises
    finished = false
    inst = HTTP::Features::Instrumentation::NullInstrumenter.new
    inst.define_singleton_method(:finish) { |_name, _payload| finished = true }
    assert_raises(RuntimeError) do
      inst.instrument("test") { raise "boom" }
    end
    assert finished
  end

  # -- with an instrumenter that unconditionally yields --

  def test_with_yielding_instrumenter_returns_the_response_even_without_payload
    yielding_instrumenter = Class.new do
      def instrument(_name, _payload = {})
        yield
      end

      def start(_name, _payload = {}); end
      def finish(_name, _payload = {}); end
    end.new

    feat = HTTP::Features::Instrumentation.new(instrumenter: yielding_instrumenter)
    req = HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      body:    "",
      request: req
    )
    result = feat.around_request(req) { resp }

    assert_same resp, result
  end

  def test_with_yielding_instrumenter_does_not_raise_local_jump_error_in_on_error
    yielding_instrumenter = Class.new do
      def instrument(_name, _payload = {})
        yield
      end

      def start(_name, _payload = {}); end
      def finish(_name, _payload = {}); end
    end.new

    feat = HTTP::Features::Instrumentation.new(instrumenter: yielding_instrumenter)
    req = HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})
    feat.on_error(req, HTTP::TimeoutError.new)
  end
end
