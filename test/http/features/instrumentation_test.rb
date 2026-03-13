# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::Instrumentation do
  cover "HTTP::Features::Instrumentation*"
  let(:instrumenter_class) do
    Class.new(HTTP::Features::Instrumentation::NullInstrumenter) do
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

  let(:instrumenter) { instrumenter_class.new }
  let(:feature) { HTTP::Features::Instrumentation.new(instrumenter: instrumenter) }

  describe "initialization" do
    it "uses NullInstrumenter when no instrumenter is provided" do
      feature = HTTP::Features::Instrumentation.new

      assert_instance_of HTTP::Features::Instrumentation::NullInstrumenter, feature.instrumenter
    end

    it "sets the name to request.http by default" do
      feature = HTTP::Features::Instrumentation.new

      assert_equal "request.http", feature.name
    end

    it "sets the error_name to error.http by default" do
      feature = HTTP::Features::Instrumentation.new

      assert_equal "error.http", feature.error_name
    end

    it "uses a custom namespace" do
      feature = HTTP::Features::Instrumentation.new(namespace: "my_app")

      assert_equal "request.my_app", feature.name
      assert_equal "error.my_app", feature.error_name
    end
  end

  describe "around_request" do
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/",
        headers: { accept: "application/json" },
        body:    '{"hello": "world!"}'
      )
    end

    let(:response) do
      HTTP::Response.new(
        version: "1.1",
        status:  200,
        headers: { content_type: "application/json" },
        body:    '{"success": true}',
        request: request
      )
    end

    it "emits a start event with the correct name before the main event" do
      feature.around_request(request) { response }

      first_event = instrumenter.events.first

      assert_equal "start_request.http", first_event[:name]
    end

    it "emits a start event with the request payload" do
      feature.around_request(request) { response }

      first_event = instrumenter.events.first

      assert_equal({ request: request }, first_event[:payload])
    end

    it "finishes the instrumentation span with the response" do
      feature.around_request(request) { response }

      last_finish = instrumenter.events.reverse.find { |e| e[:type] == :finish }

      assert_equal({ request: request, response: response }, last_finish[:payload])
    end

    it "emits the main event with the correct name" do
      feature.around_request(request) { response }

      main_finishes = instrumenter.events.select { |e| e[:type] == :finish && e[:name] == "request.http" }

      assert_equal 1, main_finishes.length
    end

    it "returns the response from the block" do
      result = feature.around_request(request) { response }

      assert_same response, result
    end

    it "passes the request to the block" do
      received = nil
      feature.around_request(request) do |req|
        received = req
        response
      end

      assert_same request, received
    end

    it "finishes the span even when the block raises" do
      assert_raises(RuntimeError) do
        feature.around_request(request) { raise "boom" }
      end

      last_finish = instrumenter.events.reverse.find { |e| e[:type] == :finish }

      assert_equal({ request: request }, last_finish[:payload])
    end
  end

  describe "on_error" do
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/",
        headers: { accept: "application/json" },
        body:    '{"hello": "world!"}'
      )
    end

    let(:error) { HTTP::TimeoutError.new }

    it "instruments the error with the correct event name" do
      feature.on_error(request, error)

      finish_event = instrumenter.events.find { |e| e[:type] == :finish }

      assert_equal "error.http", finish_event[:name]
    end

    it "logs the error payload" do
      feature.on_error(request, error)

      finish_event = instrumenter.events.find { |e| e[:type] == :finish }

      assert_equal({ request: request, error: error }, finish_event[:payload])
    end
  end

  describe "NullInstrumenter" do
    let(:null_instrumenter) { HTTP::Features::Instrumentation::NullInstrumenter.new }

    it "#start is callable" do
      null_instrumenter.start("test", {})
    end

    it "#finish is callable" do
      null_instrumenter.finish("test", {})
    end

    it "#instrument is callable without a block" do
      null_instrumenter.instrument("test")
    end

    it "#instrument yields the payload to the block" do
      received = nil
      null_instrumenter.instrument("test", { key: "value" }) { |payload| received = payload }

      assert_equal({ key: "value" }, received)
    end

    it "#instrument defaults payload to an empty hash" do
      received = nil
      null_instrumenter.instrument("test") { |payload| received = payload }

      assert_equal({}, received)
    end

    it "#instrument passes name to start and finish" do
      names = []
      instrumenter = HTTP::Features::Instrumentation::NullInstrumenter.new
      instrumenter.define_singleton_method(:start) { |name, _payload| names << [:start, name] }
      instrumenter.define_singleton_method(:finish) { |name, _payload| names << [:finish, name] }

      instrumenter.instrument("test.event") { nil }

      assert_equal [[:start, "test.event"], [:finish, "test.event"]], names
    end

    it "#instrument calls finish even when block raises" do
      finished = false
      instrumenter = HTTP::Features::Instrumentation::NullInstrumenter.new
      instrumenter.define_singleton_method(:finish) { |_name, _payload| finished = true }

      assert_raises(RuntimeError) do
        instrumenter.instrument("test") { raise "boom" }
      end

      assert finished
    end
  end

  context "with an instrumenter that unconditionally yields" do
    let(:yielding_instrumenter) do
      Class.new do
        def instrument(_name, _payload = {})
          yield
        end

        def start(_name, _payload = {}); end
        def finish(_name, _payload = {}); end
      end.new
    end

    let(:feature) { HTTP::Features::Instrumentation.new(instrumenter: yielding_instrumenter) }
    let(:request) do
      HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})
    end

    let(:response) do
      HTTP::Response.new(
        version: "1.1",
        status:  200,
        body:    "",
        request: request
      )
    end

    it "returns the response even without payload" do
      result = feature.around_request(request) { response }

      assert_same response, result
    end

    it "does not raise LocalJumpError in on_error" do
      feature.on_error(request, HTTP::TimeoutError.new)
    end
  end
end
