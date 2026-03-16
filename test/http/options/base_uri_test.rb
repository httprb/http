# frozen_string_literal: true

require "test_helper"

class HTTPOptionsBaseURITest < Minitest::Test
  cover "HTTP::Options*"

  # #with_base_uri

  def test_with_base_uri_sets_base_uri_from_a_string
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com/api")

    assert_equal "https://example.com/api", result.base_uri.to_s
  end

  def test_with_base_uri_sets_base_uri_from_an_http_uri
    opts = HTTP::Options.new
    uri = HTTP::URI.parse("https://example.com/api")
    result = opts.with_base_uri(uri)

    assert_equal "https://example.com/api", result.base_uri.to_s
  end

  def test_with_base_uri_raises_for_uri_without_scheme
    opts = HTTP::Options.new
    err = assert_raises(HTTP::Error) { opts.with_base_uri("/users") }

    assert_includes err.message, "Invalid base URI"
    assert_includes err.message, "/users"
  end

  def test_with_base_uri_raises_for_protocol_relative_uri
    opts = HTTP::Options.new
    err = assert_raises(HTTP::Error) { opts.with_base_uri("//example.com/users") }

    assert_includes err.message, "Invalid base URI"
    assert_includes err.message, "//example.com/users"
  end

  def test_with_base_uri_does_not_modify_the_original_options
    opts = HTTP::Options.new
    opts.with_base_uri("https://example.com")

    refute_predicate opts, :base_uri?
  end

  # #base_uri?

  def test_base_uri_predicate_returns_false_by_default
    opts = HTTP::Options.new

    refute_predicate opts, :base_uri?
  end

  def test_base_uri_predicate_returns_true_when_base_uri_is_set
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com")

    assert_predicate result, :base_uri?
  end

  # chaining base URIs

  def test_chaining_joins_a_relative_path_onto_existing_base_uri
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com").with_base_uri("api/v1")

    assert_equal "https://example.com/api/v1", result.base_uri.to_s
  end

  def test_chaining_joins_an_absolute_path_onto_existing_base_uri
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com/api").with_base_uri("/v2")

    assert_equal "https://example.com/v2", result.base_uri.to_s
  end

  def test_chaining_replaces_with_a_full_uri
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com/api").with_base_uri("https://other.com/v2")

    assert_equal "https://other.com/v2", result.base_uri.to_s
  end

  def test_chaining_joins_onto_base_uri_with_trailing_slash
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com/api/").with_base_uri("v2")

    assert_equal "https://example.com/api/v2", result.base_uri.to_s
  end

  def test_chaining_handles_parent_path_traversal
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com/api/v1").with_base_uri("../v2")

    assert_equal "https://example.com/api/v2", result.base_uri.to_s
  end

  def test_chaining_does_not_mutate_the_intermediate_base_uri
    opts = HTTP::Options.new
    intermediate = opts.with_base_uri("https://example.com/api")
    intermediate.with_base_uri("v2")

    assert_equal "https://example.com/api", intermediate.base_uri.to_s
  end

  # persistent and base_uri interaction

  def test_persistent_allows_compatible_persistent_and_base_uri
    opts = HTTP::Options.new
    result = opts.with_base_uri("https://example.com/api").with_persistent("https://example.com")

    assert_equal "https://example.com/api", result.base_uri.to_s
    assert_equal "https://example.com", result.persistent
  end

  def test_persistent_raises_when_persistent_origin_conflicts_with_base_uri
    opts = HTTP::Options.new
    with_base = opts.with_base_uri("https://example.com/api")

    err = assert_raises(HTTP::Error) { with_base.with_persistent("https://other.com") }
    assert_includes err.message, "https://other.com"
    assert_includes err.message, "base URI origin (https://example.com)"
  end

  def test_persistent_raises_when_base_uri_origin_conflicts_with_persistent
    opts = HTTP::Options.new
    with_persistent = opts.with_persistent("https://example.com")

    err = assert_raises(HTTP::Error) { with_persistent.with_base_uri("https://other.com/api") }
    assert_includes err.message, "https://example.com"
    assert_includes err.message, "base URI origin (https://other.com)"
  end

  def test_persistent_allows_setting_both_via_constructor_when_origins_match
    result = HTTP::Options.new(base_uri: "https://example.com/api", persistent: "https://example.com")

    assert_equal "https://example.com/api", result.base_uri.to_s
    assert_equal "https://example.com", result.persistent
  end

  def test_persistent_raises_via_constructor_when_origins_conflict
    assert_raises(HTTP::Error) do
      HTTP::Options.new(base_uri: "https://example.com/api", persistent: "https://other.com")
    end
  end
end
