# frozen_string_literal: true

require "test_helper"

describe HTTP::Headers::Normalizer do
  let(:normalizer) { HTTP::Headers::Normalizer.new }

  describe "#call" do
    it "normalizes the header" do
      assert_equal "Content-Type", normalizer.call("content_type")
    end

    it "returns a non-frozen string" do
      refute_predicate normalizer.call("content_type"), :frozen?
    end

    it "evicts the oldest item when cache is full" do
      max_headers = (1..HTTP::Headers::Normalizer::Cache::MAX_SIZE).map { |i| "Header#{i}" }
      max_headers.each { |header| normalizer.call(header) }
      normalizer.call("New-Header")
      cache_store = normalizer.instance_variable_get(:@cache).instance_variable_get(:@store)

      assert_equal(max_headers[1..] + ["New-Header"], cache_store.keys)
    end

    it "returns mutable strings" do
      normalized_headers = Array.new(3) { normalizer.call("content_type") }

      # All values should be equal
      assert_equal 1, normalized_headers.uniq.size
      # Each should be a distinct object
      assert_equal normalized_headers.size, normalized_headers.map(&:object_id).uniq.size
      # None should be frozen
      assert normalized_headers.none?(&:frozen?)
    end

    it "allocates minimal memory for normalization of the same header" do
      normalizer.call("accept") # Ensure normalizer is pre-allocated

      # On first call it is expected to allocate during normalization
      assert_allocations(Array: 1, MatchData: 1, String: 6) do
        normalizer.call("content_type")
      end

      # On subsequent call it is expected to only allocate copy of a cached string
      assert_allocations(Array: 0, MatchData: 0, String: 1) do
        normalizer.call("content_type")
      end
    end
  end
end
