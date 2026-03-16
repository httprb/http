# frozen_string_literal: true

require "test_helper"

class HTTPRetriableErrorsTest < Minitest::Test
  cover "HTTP::OutOfRetriesError*"

  def error
    @error ||= HTTP::OutOfRetriesError.new("out of retries")
  end

  # -- #response --

  def test_response_defaults_to_nil
    assert_nil error.response
  end

  def test_response_can_be_set_and_read
    sentinel = Object.new
    error.response = sentinel

    assert_same sentinel, error.response
  end

  # -- #cause --

  def test_cause_returns_nil_when_no_cause_is_set
    assert_nil error.cause
  end

  def test_cause_returns_the_explicitly_set_cause
    original = RuntimeError.new("boom")
    error.cause = original

    assert_same original, error.cause
  end

  def test_cause_returns_the_implicit_cause_when_no_explicit_cause_is_set
    implicit = RuntimeError.new("implicit")

    err = begin
      raise implicit
    rescue RuntimeError
      begin
        raise HTTP::OutOfRetriesError, "out of retries"
      rescue HTTP::OutOfRetriesError => e
        e
      end
    end

    assert_same implicit, err.cause
  end

  def test_cause_prefers_the_explicit_cause_over_the_implicit_cause
    explicit = RuntimeError.new("explicit")
    implicit = RuntimeError.new("implicit")

    err = begin
      raise implicit
    rescue RuntimeError
      begin
        raise HTTP::OutOfRetriesError, "out of retries"
      rescue HTTP::OutOfRetriesError => e
        e
      end
    end
    err.cause = explicit

    assert_same explicit, err.cause
  end
end
