# frozen_string_literal: true

require "test_helper"

describe HTTP::Headers::Normalizer do
  cover "HTTP::Headers::Normalizer*"
  let(:normalizer) { HTTP::Headers::Normalizer.new }

  before { Thread.current[HTTP::Headers::Normalizer::CACHE_KEY] = nil }

  describe "#call" do
    it "normalizes the header" do
      assert_equal "Content-Type", normalizer.call("content_type")
    end

    it "returns a non-frozen string" do
      refute_predicate normalizer.call("content_type"), :frozen?
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

    if RUBY_ENGINE == "ruby"
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

    it "calls .to_s on the name argument" do
      name = fake(to_s: "content_type")

      assert_equal "Content-Type", normalizer.call(name)
    end

    it "caches the normalized value and reuses it" do
      first  = normalizer.call("content_type")
      second = normalizer.call("content_type")

      assert_equal first, second
    end

    it "passes through names already in canonical form unchanged" do
      assert_equal "Content-Type", normalizer.call("Content-Type")
    end

    it "normalizes underscore-separated names" do
      assert_equal "Content-Type", normalizer.call("content_type")
    end

    it "normalizes dash-separated names" do
      assert_equal "Content-Type", normalizer.call("content-type")
    end

    it "raises HeaderError for invalid header names" do
      err = assert_raises(HTTP::HeaderError) { normalizer.call("invalid header") }
      assert_includes err.message, "invalid header"
    end

    it "includes inspect-formatted name in invalid header error" do
      err = assert_raises(HTTP::HeaderError) { normalizer.call("invalid header") }
      assert_includes err.message, '"invalid header"'
    end

    it "freezes the cached value internally but returns a dup" do
      result = normalizer.call("accept")

      refute_predicate result, :frozen?
      assert_equal "Accept", result
    end
  end
end
