# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::Instrumentation do
  cover "HTTP::Features::Instrumentation*"
  let(:instrumenter_class) do
    Class.new(HTTP::Features::Instrumentation::NullInstrumenter) do
      attr_reader :output

      def initialize
        super
        @output = {}
      end

      def start(_name, payload)
        output[:start] = payload
      end

      def finish(_name, payload)
        output[:finish] = payload
      end
    end
  end

  let(:instrumenter) { instrumenter_class.new }
  let(:feature) { HTTP::Features::Instrumentation.new(instrumenter: instrumenter) }

  describe "logging the request" do
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/",
        headers: { accept: "application/json" },
        body:    '{"hello": "world!"}'
      )
    end

    it "logs the request" do
      feature.wrap_request(request)

      assert_equal({ request: request }, instrumenter.output[:start])
    end
  end

  describe "logging the response" do
    let(:response) do
      HTTP::Response.new(
        version: "1.1",
        status:  200,
        headers: { content_type: "application/json" },
        body:    '{"success": true}',
        request: HTTP::Request.new(verb: :get, uri: "https://example.com")
      )
    end

    it "logs the response" do
      feature.wrap_response(response)

      assert_equal({ response: response }, instrumenter.output[:finish])
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

    it "#instrument yields the block when given" do
      result = null_instrumenter.instrument("test") { :yielded }

      assert_equal :yielded, result
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

    it "does not raise LocalJumpError in wrap_request" do
      feature.wrap_request(request)
    end

    it "does not raise LocalJumpError in on_error" do
      feature.on_error(request, HTTP::TimeoutError.new)
    end
  end

  describe "logging errors" do
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/",
        headers: { accept: "application/json" },
        body:    '{"hello": "world!"}'
      )
    end

    let(:error) { HTTP::TimeoutError.new }

    it "logs the error" do
      feature.on_error(request, error)

      assert_equal({ request: request, error: error }, instrumenter.output[:finish])
    end
  end
end
