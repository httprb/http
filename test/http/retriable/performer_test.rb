# frozen_string_literal: true

require "test_helper"

# Custom exception used across performer tests
unless defined?(CustomException)
  class CustomException < StandardError
  end
end

# Subclass for testing is_a? vs instance_of? in retry_exception?
unless defined?(CustomSubException)
  class CustomSubException < HTTP::TimeoutError
  end
end

describe HTTP::Retriable::Performer do
  cover "HTTP::Retriable::Performer*"
  let(:client) do
    HTTP::Client.new
  end

  let(:response) do
    HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      request: request
    )
  end

  let(:request) do
    HTTP::Request.new(
      verb: :get,
      uri:  "http://example.com"
    )
  end

  let(:perform_spy) { { counter: 0 } }
  let(:counter_spy) { perform_spy[:counter] }

  def perform(client_arg = client, request_arg = request, **options, &block)
    # by explicitly overwriting the default delay, we make a much faster test suite
    options = { delay: 0 }.merge(options)

    HTTP::Retriable::Performer
      .new(**options)
      .perform(client_arg, request_arg) do
        perform_spy[:counter] += 1
        block ? yield : response
      end
  end

  def measure_wait
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    [t2 - t1, result]
  end

  describe "#initialize" do
    it "coerces tries to integer" do
      performer = HTTP::Retriable::Performer.new(tries: 3.7)

      assert_equal 3, performer.instance_variable_get(:@tries)
    end

    it "coerces string tries via to_i" do
      performer = HTTP::Retriable::Performer.new(tries: "3")

      assert_equal 3, performer.instance_variable_get(:@tries)
    end

    it "truncates float-like string tries via to_i" do
      performer = HTTP::Retriable::Performer.new(tries: "3.7")

      assert_equal 3, performer.instance_variable_get(:@tries)
    end

    it "uses default delay when none is provided" do
      performer = HTTP::Retriable::Performer.new
      delay = performer.calculate_delay(1, nil)

      assert_operator delay, :>=, 0
    end
  end

  describe "#perform" do
    describe "expected exception" do
      it "retries the request" do
        assert_raises HTTP::OutOfRetriesError do
          perform(exceptions: [CustomException], tries: 2) do
            raise CustomException
          end
        end

        assert_equal 2, counter_spy
      end

      it "retries subclasses of listed exceptions" do
        assert_raises HTTP::OutOfRetriesError do
          perform(exceptions: [HTTP::TimeoutError], tries: 2) do
            raise CustomSubException
          end
        end

        assert_equal 2, counter_spy
      end
    end

    describe "unexpected exception" do
      it "does not retry the request" do
        assert_raises CustomException do
          perform(exceptions: [], tries: 2) do
            raise CustomException
          end
        end

        assert_equal 1, counter_spy
      end
    end

    describe "expected status codes" do
      def response(**options)
        HTTP::Response.new(
          status:  200,
          version: "1.1",
          headers: {},
          body:    "Hello world!",
          request: request, **options
        )
      end

      it "retries the request" do
        assert_raises HTTP::OutOfRetriesError do
          perform(retry_statuses: [200], tries: 2)
        end

        assert_equal 2, counter_spy
      end

      it "does not retry when Range does not cover the status" do
        result = perform(retry_statuses: [400...500], tries: 2) do
          response(status: 200)
        end

        assert_equal 200, result.status.to_i
      end

      it "does not retry when Numeric does not match the status" do
        result = perform(retry_statuses: [500], tries: 2) do
          response(status: 200)
        end

        assert_equal 200, result.status.to_i
      end

      it "does not retry when proc returns false" do
        result = perform(retry_statuses: [->(s) { s >= 500 }], tries: 2) do
          response(status: 200)
        end

        assert_equal 200, result.status.to_i
      end

      describe "status codes can be expressed in many ways" do
        [
          301,
          [200, 301, 485],
          250...400,
          [250...Float::INFINITY],
          ->(status_code) { status_code == 301 },
          [->(status_code) { status_code == 301 }]
        ].each do |retry_statuses|
          it retry_statuses.to_s do
            assert_raises HTTP::OutOfRetriesError do
              perform(retry_statuses: retry_statuses, tries: 2) do
                response(status: 301)
              end
            end
          end
        end
      end
    end

    describe "unexpected status code" do
      it "does not retry the request" do
        result = perform(retry_statuses: [], tries: 2)

        assert_equal response, result

        assert_equal 1, counter_spy
      end
    end

    describe "on_retry callback" do
      it "calls the on_retry callback on each retry with exception" do
        callback_call_spy = 0

        callback_spy = proc do |callback_request, error, callback_response|
          assert_equal request, callback_request
          assert_kind_of HTTP::TimeoutError, error
          assert_nil callback_response
          callback_call_spy += 1
        end

        assert_raises HTTP::OutOfRetriesError do
          perform(tries: 3, on_retry: callback_spy) do
            raise HTTP::TimeoutError
          end
        end

        assert_equal 2, callback_call_spy
      end

      it "calls the on_retry callback on each retry with response" do
        callback_call_spy = 0

        callback_spy = proc do |callback_request, error, callback_response|
          assert_equal request, callback_request
          assert_nil error
          assert_equal response, callback_response
          callback_call_spy += 1
        end

        assert_raises HTTP::OutOfRetriesError do
          perform(retry_statuses: [200], tries: 3, on_retry: callback_spy)
        end

        assert_equal 2, callback_call_spy
      end
    end

    describe "delay option" do
      it "sleeps for the calculated delay" do
        slept_values = []
        performer = HTTP::Retriable::Performer.new(delay: 0.123, tries: 2, should_retry: ->(*) { true })
        performer.define_singleton_method(:sleep) { |d| slept_values << d }

        assert_raises(HTTP::OutOfRetriesError) do
          performer.perform(client, request) { response }
        end

        assert_equal [0.123], slept_values
      end

      let(:timing_slack) { 0.5 }

      it "can be a positive number" do
        time, = measure_wait do
          assert_raises(HTTP::OutOfRetriesError) do
            perform(delay: 0.02, tries: 3, should_retry: ->(*) { true })
          end
        end

        assert_in_delta 0.04, time, timing_slack
      end

      it "can be a proc number" do
        time, = measure_wait do
          assert_raises(HTTP::OutOfRetriesError) do
            perform(delay: ->(attempt) { attempt / 50.0 }, tries: 3, should_retry: ->(*) { true })
          end
        end

        assert_in_delta 0.06, time, timing_slack
      end

      it "receives correct retry number when a proc" do
        retry_count = 0
        retry_proc = proc do |attempt|
          assert_equal retry_count, attempt
          assert_operator attempt, :>, 0
          0
        end
        assert_raises(HTTP::OutOfRetriesError) do
          perform(delay: retry_proc, should_retry: ->(*) { true }) do
            retry_count += 1
            response
          end
        end
      end

      it "respects max_delay option" do
        time, = measure_wait do
          assert_raises(HTTP::OutOfRetriesError) do
            perform(delay: 100, max_delay: 0.02, tries: 3, should_retry: ->(*) { true })
          end
        end

        assert_in_delta 0.04, time, timing_slack
      end
    end

    describe "should_retry option" do
      it "decides if the request should be retried" do
        retry_proc = proc do |req, err, res, attempt|
          assert_equal request, req
          if res
            assert_nil err
            assert_equal response, res
          else
            assert_kind_of CustomException, err
            assert_nil res
          end

          attempt < 5
        end

        begin
          perform(should_retry: retry_proc) do
            rand < 0.5 ? response : raise(CustomException)
          end
        rescue CustomException
          nil
        end

        assert_equal 5, counter_spy
      end

      it "passes the exception to should_retry proc" do
        received_err = nil
        retry_proc = proc do |_req, err, _res, _attempt|
          received_err = err
          false
        end

        assert_raises CustomException do
          perform(should_retry: retry_proc) do
            raise CustomException
          end
        end

        assert_kind_of CustomException, received_err
      end

      it "raises the original error if not retryable" do
        retry_proc = ->(*) { false }

        assert_raises CustomException do
          perform(should_retry: retry_proc) do
            raise CustomException
          end
        end

        assert_equal 1, counter_spy
      end

      it "raises HTTP::OutOfRetriesError if retryable" do
        retry_proc = ->(*) { true }

        assert_raises HTTP::OutOfRetriesError do
          perform(should_retry: retry_proc) do
            raise CustomException
          end
        end

        assert_equal 5, counter_spy
      end
    end
  end

  describe "#calculate_delay" do
    it "passes the response to the delay calculator" do
      responses_seen = []

      performer = HTTP::Retriable::Performer.new(delay: 0, retry_statuses: [200], tries: 2)
      calculator = performer.instance_variable_get(:@delay_calculator)
      original_call = calculator.method(:call)
      calculator.define_singleton_method(:call) do |iteration, resp|
        responses_seen << resp
        original_call.call(iteration, resp)
      end

      begin
        performer.perform(client, request) { response }
      rescue HTTP::OutOfRetriesError
        nil
      end

      assert_equal response, responses_seen.first
    end
  end

  describe "when block returns nil" do
    it "continues iterating" do
      call_count = 0
      perform(tries: 3) do
        call_count += 1
        call_count < 2 ? nil : response
      end

      assert_equal 2, call_count
    end
  end

  describe "connection closing" do
    it "does not close the connection if we get a proper response" do
      close_called = false
      mock_client = fake(close: ->(*) { close_called = true })
      perform(mock_client)

      refute close_called
    end

    it "closes the connection after each raised attempt" do
      close_count = 0
      mock_client = fake(close: ->(*) { close_count += 1 })

      assert_raises(HTTP::OutOfRetriesError) do
        perform(mock_client, should_retry: ->(*) { true }, tries: 3)
      end

      assert_equal 3, close_count
    end

    it "closes the connection on an unexpected exception" do
      close_count = 0
      mock_client = fake(close: ->(*) { close_count += 1 })

      assert_raises(CustomException) do
        perform(mock_client) do
          raise CustomException
        end
      end

      assert_equal 1, close_count
    end
  end

  describe "response flushing on exhausted retries" do
    it "flushes the response when retries are exhausted with a response" do
      flushed = false
      flush_response = HTTP::Response.new(
        status:  503,
        version: "1.1",
        headers: {},
        body:    "Service Unavailable",
        request: request
      )
      flush_response.define_singleton_method(:flush) do
        flushed = true
        self
      end

      begin
        HTTP::Retriable::Performer
          .new(delay: 0, retry_statuses: [503], tries: 2)
          .perform(client, request) { flush_response }
      rescue HTTP::OutOfRetriesError
        nil
      end

      assert flushed, "expected response to be flushed on final attempt"
    end
  end

  describe HTTP::OutOfRetriesError do
    it "has the original exception as a cause if available" do
      err = nil
      begin
        perform(exceptions: [CustomException]) do
          raise CustomException
        end
      rescue HTTP::OutOfRetriesError => e
        err = e
      end

      assert_kind_of CustomException, err.cause
    end

    it "has the last raised response as an attribute" do
      err = nil
      begin
        perform(should_retry: ->(*) { true })
      rescue HTTP::OutOfRetriesError => e
        err = e
      end

      assert_equal response, err.response
    end

    it "has a message containing the verb and URI" do
      err = nil
      begin
        perform(exceptions: [CustomException]) do
          raise CustomException
        end
      rescue HTTP::OutOfRetriesError => e
        err = e
      end

      assert_includes err.message, "GET"
      assert_includes err.message, "http://example.com"
      assert_includes err.message, "failed"
    end

    it "includes the status in the message when a response is present" do
      err = nil
      begin
        perform(retry_statuses: [200], tries: 2)
      rescue HTTP::OutOfRetriesError => e
        err = e
      end

      assert_includes err.message, "200"
      assert_includes err.message, "GET"
      assert_includes err.message, "http://example.com"
    end

    it "includes the exception in the message when an exception is present" do
      err = nil
      begin
        perform(exceptions: [CustomException]) do
          raise CustomException, "something went wrong"
        end
      rescue HTTP::OutOfRetriesError => e
        err = e
      end

      assert_includes err.message, "something went wrong"
    end

    it "does not include the status when no response is present" do
      err = nil
      begin
        perform(exceptions: [CustomException]) do
          raise CustomException
        end
      rescue HTTP::OutOfRetriesError => e
        err = e
      end

      refute_includes err.message, " with "
    end

    it "does not include the exception when no exception is present" do
      err = nil
      begin
        perform(retry_statuses: [200], tries: 2)
      rescue HTTP::OutOfRetriesError => e
        err = e
      end

      # Message should end with the status, not have ":<exception>" appended
      assert_match(/failed with [\w ]+\z/, err.message)
      assert_includes err.message, " with "
    end
  end
end
