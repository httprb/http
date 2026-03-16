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

class HTTPRetriablePerformerTest < Minitest::Test
  cover "HTTP::Retriable::Performer*"

  def client
    @client ||= HTTP::Client.new
  end

  def response
    @response ||= HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      request: request
    )
  end

  def request
    @request ||= HTTP::Request.new(
      verb: :get,
      uri:  "http://example.com"
    )
  end

  def setup
    super
    @perform_spy = { counter: 0 }
  end

  def counter_spy
    @perform_spy[:counter]
  end

  def perform(client_arg = client, request_arg = request, **options, &block)
    # by explicitly overwriting the default delay, we make a much faster test suite
    options = { delay: 0 }.merge(options)

    HTTP::Retriable::Performer
      .new(**options)
      .perform(client_arg, request_arg) do
        @perform_spy[:counter] += 1
        block ? yield : response
      end
  end

  def measure_wait
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    [t2 - t1, result]
  end

  # -- #initialize --

  def test_initialize_coerces_tries_to_integer
    performer = HTTP::Retriable::Performer.new(tries: 3.7)

    assert_equal 3, performer.instance_variable_get(:@tries)
  end

  def test_initialize_coerces_string_tries_via_to_i
    performer = HTTP::Retriable::Performer.new(tries: "3")

    assert_equal 3, performer.instance_variable_get(:@tries)
  end

  def test_initialize_truncates_float_like_string_tries_via_to_i
    performer = HTTP::Retriable::Performer.new(tries: "3.7")

    assert_equal 3, performer.instance_variable_get(:@tries)
  end

  def test_initialize_uses_default_delay_when_none_provided
    performer = HTTP::Retriable::Performer.new
    delay = performer.calculate_delay(1, nil)

    assert_operator delay, :>=, 0
  end

  # -- #perform: expected exception --

  def test_perform_expected_exception_retries_the_request
    assert_raises HTTP::OutOfRetriesError do
      perform(exceptions: [CustomException], tries: 2) do
        raise CustomException
      end
    end
    assert_equal 2, counter_spy
  end

  def test_perform_expected_exception_retries_subclasses_of_listed_exceptions
    assert_raises HTTP::OutOfRetriesError do
      perform(exceptions: [HTTP::TimeoutError], tries: 2) do
        raise CustomSubException
      end
    end
    assert_equal 2, counter_spy
  end

  # -- #perform: unexpected exception --

  def test_perform_unexpected_exception_does_not_retry
    assert_raises CustomException do
      perform(exceptions: [], tries: 2) do
        raise CustomException
      end
    end
    assert_equal 1, counter_spy
  end

  # -- #perform: expected status codes --

  def make_response(**)
    HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      request: request, **
    )
  end

  def test_perform_expected_status_retries_the_request
    assert_raises HTTP::OutOfRetriesError do
      perform(retry_statuses: [200], tries: 2)
    end
    assert_equal 2, counter_spy
  end

  def test_perform_does_not_retry_when_range_does_not_cover_status
    result = perform(retry_statuses: [400...500], tries: 2) do
      make_response(status: 200)
    end

    assert_equal 200, result.status.to_i
  end

  def test_perform_does_not_retry_when_numeric_does_not_match_status
    result = perform(retry_statuses: [500], tries: 2) do
      make_response(status: 200)
    end

    assert_equal 200, result.status.to_i
  end

  def test_perform_does_not_retry_when_proc_returns_false
    result = perform(retry_statuses: [->(s) { s >= 500 }], tries: 2) do
      make_response(status: 200)
    end

    assert_equal 200, result.status.to_i
  end

  # -- status codes expressed in many ways --

  [
    301,
    301.0,
    [200, 301, 485],
    250...400,
    [250...Float::INFINITY],
    ->(status_code) { status_code == 301 },
    [->(status_code) { status_code == 301 }]
  ].each do |retry_statuses|
    define_method(:"test_perform_status_codes_#{retry_statuses}") do
      assert_raises HTTP::OutOfRetriesError do
        perform(retry_statuses: retry_statuses, tries: 2) do
          make_response(status: 301)
        end
      end
    end
  end

  # -- unexpected status code --

  def test_perform_unexpected_status_does_not_retry
    result = perform(retry_statuses: [], tries: 2)

    assert_equal response, result
    assert_equal 1, counter_spy
  end

  # -- on_retry callback --

  def test_on_retry_callback_with_exception
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

  def test_on_retry_callback_with_response
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

  # -- delay option --

  def test_delay_sleeps_for_the_calculated_delay
    slept_values = []
    performer = HTTP::Retriable::Performer.new(delay: 0.123, tries: 2, should_retry: ->(*) { true })
    performer.define_singleton_method(:sleep) { |d| slept_values << d }

    assert_raises(HTTP::OutOfRetriesError) do
      performer.perform(client, request) { response }
    end

    assert_equal [0.123], slept_values
  end

  def test_delay_can_be_a_positive_number
    timing_slack = 0.5
    time, = measure_wait do
      assert_raises(HTTP::OutOfRetriesError) do
        perform(delay: 0.02, tries: 3, should_retry: ->(*) { true })
      end
    end

    assert_in_delta 0.04, time, timing_slack
  end

  def test_delay_can_be_a_proc_number
    timing_slack = 0.5
    time, = measure_wait do
      assert_raises(HTTP::OutOfRetriesError) do
        perform(delay: ->(attempt) { attempt / 50.0 }, tries: 3, should_retry: ->(*) { true })
      end
    end

    assert_in_delta 0.06, time, timing_slack
  end

  def test_delay_receives_correct_retry_number_when_a_proc
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

  def test_delay_respects_max_delay_option
    timing_slack = 0.5
    time, = measure_wait do
      assert_raises(HTTP::OutOfRetriesError) do
        perform(delay: 100, max_delay: 0.02, tries: 3, should_retry: ->(*) { true })
      end
    end

    assert_in_delta 0.04, time, timing_slack
  end

  # -- should_retry option --

  def test_should_retry_decides_if_request_should_be_retried
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

  def test_should_retry_passes_the_exception_to_proc
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

  def test_should_retry_raises_original_error_if_not_retryable
    retry_proc = ->(*) { false }

    assert_raises CustomException do
      perform(should_retry: retry_proc) do
        raise CustomException
      end
    end

    assert_equal 1, counter_spy
  end

  def test_should_retry_raises_out_of_retries_error_if_retryable
    retry_proc = ->(*) { true }

    assert_raises HTTP::OutOfRetriesError do
      perform(should_retry: retry_proc) do
        raise CustomException
      end
    end

    assert_equal 5, counter_spy
  end

  # -- #calculate_delay --

  def test_calculate_delay_passes_response_to_delay_calculator
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

  # -- when block returns nil --

  def test_when_block_returns_nil_continues_iterating
    call_count = 0
    perform(tries: 3) do
      call_count += 1
      call_count < 2 ? nil : response
    end

    assert_equal 2, call_count
  end

  # -- connection closing --

  def test_connection_closing_does_not_close_on_proper_response
    close_called = false
    mock_client = fake(close: ->(*) { close_called = true })
    perform(mock_client)

    refute close_called
  end

  def test_connection_closing_closes_after_each_raised_attempt
    close_count = 0
    mock_client = fake(close: ->(*) { close_count += 1 })

    assert_raises(HTTP::OutOfRetriesError) do
      perform(mock_client, should_retry: ->(*) { true }, tries: 3)
    end

    assert_equal 3, close_count
  end

  def test_connection_closing_closes_on_unexpected_exception
    close_count = 0
    mock_client = fake(close: ->(*) { close_count += 1 })

    assert_raises(CustomException) do
      perform(mock_client) do
        raise CustomException
      end
    end

    assert_equal 1, close_count
  end

  # -- response flushing on exhausted retries --

  def test_response_flushing_flushes_when_retries_exhausted
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

  # -- HTTP::OutOfRetriesError --

  def test_out_of_retries_error_has_original_exception_as_cause
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

  def test_out_of_retries_error_has_last_response_as_attribute
    err = nil
    begin
      perform(should_retry: ->(*) { true })
    rescue HTTP::OutOfRetriesError => e
      err = e
    end

    assert_equal response, err.response
  end

  def test_out_of_retries_error_has_message_containing_verb_and_uri
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

  def test_out_of_retries_error_includes_status_when_response_present
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

  def test_out_of_retries_error_includes_exception_in_message
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

  def test_out_of_retries_error_does_not_include_status_when_no_response
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

  def test_out_of_retries_error_does_not_include_exception_when_no_exception
    err = nil
    begin
      perform(retry_statuses: [200], tries: 2)
    rescue HTTP::OutOfRetriesError => e
      err = e
    end

    assert_match(/failed with [\w ]+\z/, err.message)
    assert_includes err.message, " with "
  end
end
