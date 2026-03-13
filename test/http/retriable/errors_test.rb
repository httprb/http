# frozen_string_literal: true

require "test_helper"

describe HTTP::OutOfRetriesError do
  cover "HTTP::OutOfRetriesError*"

  let(:error) { HTTP::OutOfRetriesError.new("out of retries") }

  describe "#response" do
    it "defaults to nil" do
      assert_nil error.response
    end

    it "can be set and read" do
      sentinel = Object.new
      error.response = sentinel

      assert_same sentinel, error.response
    end
  end

  describe "#cause" do
    it "returns nil when no cause is set" do
      assert_nil error.cause
    end

    it "returns the explicitly set cause" do
      original = RuntimeError.new("boom")
      error.cause = original

      assert_same original, error.cause
    end

    it "returns the implicit cause when no explicit cause is set" do
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

    it "prefers the explicit cause over the implicit cause" do
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
end
