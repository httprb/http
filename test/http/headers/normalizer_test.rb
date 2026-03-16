# frozen_string_literal: true

require "test_helper"

class HTTPHeadersNormalizerTest < Minitest::Test
  cover "HTTP::Headers::Normalizer*"

  def normalizer
    @normalizer ||= HTTP::Headers::Normalizer.new
  end

  def setup
    super
    Thread.current[HTTP::Headers::Normalizer::CACHE_KEY] = nil
  end

  def test_call_normalizes_the_header
    assert_equal "Content-Type", normalizer.call("content_type")
  end

  def test_call_returns_a_non_frozen_string
    refute_predicate normalizer.call("content_type"), :frozen?
  end

  def test_call_returns_mutable_strings
    normalized_headers = Array.new(3) { normalizer.call("content_type") }

    # All values should be equal
    assert_equal 1, normalized_headers.uniq.size
    # Each should be a distinct object
    assert_equal normalized_headers.size, normalized_headers.map(&:object_id).uniq.size
    # None should be frozen
    assert normalized_headers.none?(&:frozen?)
  end

  if RUBY_ENGINE == "ruby"
    def test_call_allocates_minimal_memory_for_normalization_of_the_same_header
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

  def test_call_calls_to_s_on_the_name_argument
    name = fake(to_s: "content_type")

    assert_equal "Content-Type", normalizer.call(name)
  end

  def test_call_caches_the_normalized_value_and_reuses_it
    first  = normalizer.call("content_type")
    second = normalizer.call("content_type")

    assert_equal first, second
  end

  def test_call_passes_through_names_already_in_canonical_form
    assert_equal "Content-Type", normalizer.call("Content-Type")
  end

  def test_call_normalizes_underscore_separated_names
    assert_equal "Content-Type", normalizer.call("content_type")
  end

  def test_call_normalizes_dash_separated_names
    assert_equal "Content-Type", normalizer.call("content-type")
  end

  def test_call_raises_header_error_for_invalid_header_names
    err = assert_raises(HTTP::HeaderError) { normalizer.call("invalid header") }
    assert_includes err.message, "invalid header"
  end

  def test_call_includes_inspect_formatted_name_in_invalid_header_error
    err = assert_raises(HTTP::HeaderError) { normalizer.call("invalid header") }
    assert_includes err.message, '"invalid header"'
  end

  def test_call_freezes_cached_value_internally_but_returns_a_dup
    result = normalizer.call("accept")

    refute_predicate result, :frozen?
    assert_equal "Accept", result
  end
end
