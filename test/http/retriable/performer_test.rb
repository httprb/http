# frozen_string_literal: true

require "test_helper"

# Custom exception used across performer tests
unless defined?(CustomException)
  class CustomException < StandardError
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

  def perform(options = {}, client_arg = client, request_arg = request, &block)
    # by explicitly overwriting the default delay, we make a much faster test suite
    default_options = { delay: 0 }
    options = default_options.merge(options)

    HTTP::Retriable::Performer
      .new(options)
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
          {
            status:  200,
            version: "1.1",
            headers: {},
            body:    "Hello world!",
            request: request
          }.merge(options)
        )
      end

      it "retries the request" do
        assert_raises HTTP::OutOfRetriesError do
          perform(retry_statuses: [200], tries: 2)
        end

        assert_equal 2, counter_spy
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
      let(:timing_slack) { 0.05 }

      it "can be a positive number" do
        time, = measure_wait do
          perform(delay: 0.02, tries: 3, should_retry: ->(*) { true })
        rescue HTTP::OutOfRetriesError # rubocop:disable Lint/SuppressedException
        end

        assert_in_delta 0.04, time, timing_slack
      end

      it "can be a proc number" do
        time, = measure_wait do
          perform(delay: ->(attempt) { attempt / 50.0 }, tries: 3, should_retry: ->(*) { true })
        rescue HTTP::OutOfRetriesError # rubocop:disable Lint/SuppressedException
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
        begin
          perform(delay: retry_proc, should_retry: ->(*) { true }) do
            retry_count += 1
            response
          end
        rescue HTTP::OutOfRetriesError # rubocop:disable Lint/SuppressedException
        end
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
        rescue CustomException # rubocop:disable Lint/SuppressedException
        end

        assert_equal 5, counter_spy
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
      perform({}, mock_client)

      refute close_called
    end

    it "closes the connection after each raised attempt" do
      close_count = 0
      mock_client = fake(close: ->(*) { close_count += 1 })

      begin
        perform({ should_retry: ->(*) { true }, tries: 3 }, mock_client)
      rescue HTTP::OutOfRetriesError # rubocop:disable Lint/SuppressedException
      end

      assert_equal 3, close_count
    end

    it "closes the connection on an unexpected exception" do
      close_count = 0
      mock_client = fake(close: ->(*) { close_count += 1 })

      begin
        perform({}, mock_client) do
          raise CustomException
        end
      rescue CustomException # rubocop:disable Lint/SuppressedException
      end

      assert_equal 1, close_count
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
  end
end
