# frozen_string_literal: true

require "test_helper"

class HTTPRequestBuilderTest < Minitest::Test
  cover "HTTP::Request::Builder*"

  def build_builder(**option_overrides)
    HTTP::Request::Builder.new(HTTP::Options.new(**option_overrides))
  end

  # #build basics

  def test_build_returns_an_http_request
    builder = build_builder
    request = builder.build(:get, "http://example.com/path")

    assert_kind_of HTTP::Request, request
  end

  def test_build_sets_the_verb_on_the_request
    builder = build_builder
    request = builder.build(:get, "http://example.com/path")

    assert_equal :get, request.verb
  end

  def test_build_sets_the_uri_on_the_request
    builder = build_builder
    request = builder.build(:get, "http://example.com/path")

    assert_equal "/path", request.uri.path
  end

  def test_build_sets_connection_close_by_default
    builder = build_builder
    request = builder.build(:get, "http://example.com/path")

    assert_equal HTTP::Connection::CLOSE, request.headers["Connection"]
  end

  def test_build_sets_the_proxy_from_options
    opts = HTTP::Options.new(proxy: { proxy_address: "proxy.example.com" })
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:get, "http://example.com/")

    assert_equal({ proxy_address: "proxy.example.com" }, req.proxy)
  end

  def test_build_with_persistent_connection_sets_keep_alive
    builder = build_builder(persistent: "http://example.com")
    request = builder.build(:get, "http://example.com/path")

    assert_equal HTTP::Connection::KEEP_ALIVE, request.headers["Connection"]
  end

  def test_build_when_uri_has_empty_path_sets_path_to_slash
    builder = build_builder
    request = builder.build(:get, "http://example.com")

    assert_equal "/", request.uri.path
  end

  def test_build_when_uri_has_a_non_empty_path_preserves_it
    builder = build_builder
    request = builder.build(:get, "http://example.com/foo")

    assert_equal "/foo", request.uri.path
  end

  def test_build_with_query_params_in_options_merges_into_uri_query
    builder = build_builder(params: { "foo" => "bar" })
    request = builder.build(:get, "http://example.com/path")

    assert_includes request.uri.query, "foo=bar"
  end

  def test_build_with_query_params_and_existing_query_preserves_existing
    builder = build_builder(params: { "extra" => "val" })
    request = builder.build(:get, "http://example.com/path?existing=1")

    assert_includes request.uri.query, "existing=1"
  end

  def test_build_with_query_params_and_existing_query_appends_new_params
    builder = build_builder(params: { "extra" => "val" })
    request = builder.build(:get, "http://example.com/path?existing=1")

    assert_includes request.uri.query, "extra=val"
  end

  def test_build_with_body_in_options_uses_body
    builder = build_builder(body: "raw body")
    req = builder.build(:post, "http://example.com/")
    chunks = req.body.enum_for(:each).map(&:dup)

    assert_equal ["raw body"], chunks
  end

  def test_build_with_form_data_in_options_sets_content_type_header
    builder = build_builder(form: { "key" => "value" })
    req = builder.build(:post, "http://example.com/")

    refute_nil req.headers["Content-Type"]
  end

  def test_build_with_form_data_in_options_includes_form_data_in_body
    builder = build_builder(form: { "key" => "value" })
    req = builder.build(:post, "http://example.com/")
    chunks = req.body.enum_for(:each).map(&:dup)
    body_str = chunks.join

    assert_includes body_str, "key=value"
  end

  def test_build_with_json_in_options_encodes_json_body
    builder = build_builder(json: { "key" => "value" })
    req = builder.build(:post, "http://example.com/")
    chunks = req.body.enum_for(:each).map(&:dup)

    assert_equal [{ "key" => "value" }.to_json], chunks
  end

  def test_build_with_json_in_options_sets_content_type_to_application_json
    builder = build_builder(json: { "key" => "value" })
    req = builder.build(:post, "http://example.com/")

    assert_match(%r{\Aapplication/json}, req.headers["Content-Type"])
  end

  def test_build_with_normalize_uri_feature_passes_custom_normalizer
    custom_normalizer = ->(uri) { HTTP::URI::NORMALIZER.call(uri) }
    builder = build_builder(features: { normalize_uri: { normalizer: custom_normalizer } })
    req = builder.build(:get, "http://example.com/path")

    assert_same custom_normalizer, req.uri_normalizer
  end

  def test_build_without_normalize_uri_feature_uses_default_normalizer
    builder = build_builder
    req = builder.build(:get, "http://example.com/path")

    assert_equal HTTP::URI::NORMALIZER, req.uri_normalizer
  end

  def test_build_with_an_object_responding_to_to_s_as_uri_converts_it
    builder = build_builder
    uri_obj = Object.new
    uri_obj.define_singleton_method(:to_s) { "http://example.com/converted" }
    req = builder.build(:get, uri_obj)

    assert_equal "/converted", req.uri.path
  end

  def test_build_with_uri_object_and_base_uri_converts_non_string_uri
    builder = build_builder(base_uri: "http://example.com/api/")
    uri_obj = Object.new
    uri_obj.define_singleton_method(:to_s) { "users" }
    req = builder.build(:get, uri_obj)

    assert_equal "example.com", req.uri.host
    assert_equal "/api/users", req.uri.path
  end

  def test_build_with_a_feature_that_wraps_the_request_returns_wrapped
    wrapped = nil
    feature_class = Class.new(HTTP::Feature) do
      define_method(:wrap_request) do |req|
        wrapped = HTTP::Request.new(
          verb: req.verb,
          uri:  "http://wrapped.example.com/wrapped"
        )
        wrapped
      end
    end

    HTTP::Options.register_feature(:test_build_wrap, feature_class)
    begin
      opts = HTTP::Options.new(features: { test_build_wrap: {} })
      b = HTTP::Request::Builder.new(opts)
      result = b.build(:get, "http://example.com/original")

      assert_same wrapped, result
      assert_equal "/wrapped", result.uri.path
    ensure
      HTTP::Options.available_features.delete(:test_build_wrap)
    end
  end

  # #build with base_uri

  def test_build_with_base_uri_when_uri_is_relative_resolves_against_base
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "users")

    assert_equal "example.com", req.uri.host
    assert_match(%r{/api/users}, req.uri.path)
  end

  def test_build_with_base_uri_path_not_ending_with_slash_appends_slash
    builder = build_builder(base_uri: "http://example.com/api")
    req = builder.build(:get, "users")

    assert_equal "example.com", req.uri.host
    assert_match(%r{/api/users}, req.uri.path)
  end

  def test_build_with_base_uri_path_not_ending_with_slash_does_not_mutate_original
    options = HTTP::Options.new(base_uri: "http://example.com/api")
    builder = HTTP::Request::Builder.new(options)
    original_path = options.base_uri.path.dup
    builder.build(:get, "users")

    assert_equal original_path, options.base_uri.path
  end

  def test_build_with_base_uri_path_ending_with_slash_does_not_double_it
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "users")

    assert_equal "/api/users", req.uri.path
  end

  def test_build_with_base_uri_and_absolute_http_uri_does_not_use_base
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "http://other.com/path")

    assert_equal "other.com", req.uri.host
    assert_equal "/path", req.uri.path
  end

  def test_build_with_base_uri_and_absolute_https_uri_does_not_use_base
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "https://secure.example.com/path")

    assert_equal "secure.example.com", req.uri.host
  end

  def test_build_with_base_uri_resolves_correctly_when_base_is_set
    opts = HTTP::Options.new(base_uri: "http://example.com/")
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:get, "relative")

    assert_equal "example.com", req.uri.host
  end

  # #build with persistent

  def test_build_with_persistent_when_uri_is_relative_prepends_persistent_origin
    builder = build_builder(persistent: "http://example.com")
    req = builder.build(:get, "/path")

    assert_equal "example.com", req.uri.host
    assert_equal "/path", req.uri.path
  end

  def test_build_with_persistent_does_not_prepend_when_not_persistent
    non_persistent_opts = HTTP::Options.new
    b = HTTP::Request::Builder.new(non_persistent_opts)
    req = b.build(:get, "http://fallback.com/path")

    assert_equal "fallback.com", req.uri.host
  end

  def test_build_with_persistent_when_uri_is_absolute_uses_absolute_uri
    builder = build_builder(persistent: "http://example.com")
    req = builder.build(:get, "http://other.com/path")

    assert_equal "other.com", req.uri.host
  end

  # #wrap

  def test_wrap_returns_the_request_when_no_features_configured
    builder = build_builder
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    result = builder.wrap(req)

    assert_same req, result
  end

  def test_wrap_with_a_feature_applies_feature_wrapping
    wrapped_request = nil
    feature_class = Class.new(HTTP::Feature) do
      define_method(:wrap_request) do |req|
        wrapped_request = req
        req
      end
    end

    HTTP::Options.register_feature(:test_wrap_builder, feature_class)
    begin
      opts = HTTP::Options.new(features: { test_wrap_builder: {} })
      b = HTTP::Request::Builder.new(opts)
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")
      b.wrap(req)

      assert_same req, wrapped_request
    ensure
      HTTP::Options.available_features.delete(:test_wrap_builder)
    end
  end

  def test_wrap_with_multiple_features_applies_in_order
    call_order = []
    feature_a = Class.new(HTTP::Feature) do
      define_method(:wrap_request) do |req|
        call_order << :a
        req
      end
    end
    feature_b = Class.new(HTTP::Feature) do
      define_method(:wrap_request) do |req|
        call_order << :b
        req
      end
    end

    HTTP::Options.register_feature(:test_wrap_a, feature_a)
    HTTP::Options.register_feature(:test_wrap_b, feature_b)
    begin
      opts = HTTP::Options.new(features: { test_wrap_a: {}, test_wrap_b: {} })
      b = HTTP::Request::Builder.new(opts)
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")
      b.wrap(req)

      assert_equal %i[a b], call_order
    ensure
      HTTP::Options.available_features.delete(:test_wrap_a)
      HTTP::Options.available_features.delete(:test_wrap_b)
    end
  end

  # make_request_body (via #build)

  def test_make_request_body_when_body_option_is_set_uses_body_directly
    builder = build_builder(body: "raw")
    req = builder.build(:post, "http://example.com/")
    chunks = req.body.enum_for(:each).map(&:dup)

    assert_equal ["raw"], chunks
  end

  def test_make_request_body_when_form_option_is_set_creates_form_data
    builder = build_builder(form: { "name" => "test" })
    req = builder.build(:post, "http://example.com/")

    refute_nil req.headers["Content-Type"]
  end

  def test_make_request_body_when_form_option_is_set_returns_form_data_body_source
    builder = build_builder(form: { "name" => "test" })
    req = builder.build(:post, "http://example.com/")

    refute_nil req.body.source
  end

  def test_make_request_body_form_does_not_override_existing_content_type
    opts = HTTP::Options.new(
      form:    { "name" => "test" },
      headers: { "Content-Type" => "custom/type" }
    )
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:post, "http://example.com/")

    assert_equal "custom/type", req.headers["Content-Type"]
  end

  def test_make_request_body_when_json_option_is_set_encodes_as_json
    builder = build_builder(json: { "key" => "val" })
    req = builder.build(:post, "http://example.com/")
    chunks = req.body.enum_for(:each).map(&:dup)

    assert_equal [{ "key" => "val" }.to_json], chunks
  end

  def test_make_request_body_json_includes_charset_in_content_type
    builder = build_builder(json: { "key" => "val" })
    req = builder.build(:post, "http://example.com/")

    assert_match(/charset=utf-8/, req.headers["Content-Type"])
  end

  def test_make_request_body_json_does_not_override_existing_content_type
    opts = HTTP::Options.new(
      json:    { "key" => "val" },
      headers: { "Content-Type" => "custom/json" }
    )
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:post, "http://example.com/")

    assert_equal "custom/json", req.headers["Content-Type"]
  end

  def test_make_request_body_when_no_body_form_or_json_has_nil_body_source
    builder = build_builder
    req = builder.build(:get, "http://example.com/")

    assert_nil req.body.source
  end

  # make_form_data (via #build)

  def test_make_form_data_with_hash_form_creates_form_data
    builder = build_builder(form: { "field" => "value" })
    req = builder.build(:post, "http://example.com/")

    refute_nil req.headers["Content-Type"]
  end

  def test_make_form_data_with_hash_form_passes_data_through_to_body
    builder = build_builder(form: { "field" => "value" })
    req = builder.build(:post, "http://example.com/")
    chunks = req.body.enum_for(:each).map(&:dup)
    body_str = chunks.join

    assert_includes body_str, "field=value"
  end

  def test_make_form_data_with_multipart_form_passes_through
    multipart = HTTP::FormData::Multipart.new({ "part" => HTTP::FormData::Part.new("val") })
    opts = HTTP::Options.new(form: multipart)
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:post, "http://example.com/")

    assert_match(%r{\Amultipart/form-data}, req.headers["Content-Type"])
  end

  def test_make_form_data_with_urlencoded_form_passes_through
    urlencoded = HTTP::FormData::Urlencoded.new({ "field" => "value" })
    opts = HTTP::Options.new(form: urlencoded)
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:post, "http://example.com/")

    assert_equal "application/x-www-form-urlencoded", req.headers["Content-Type"]
  end

  # merge_query_params!

  def test_merge_query_params_when_params_is_nil_does_not_add_query_string
    builder = build_builder
    req = builder.build(:get, "http://example.com/path")

    assert_nil req.uri.query
  end

  def test_merge_query_params_when_params_is_empty_does_not_add_query_string
    builder = build_builder(params: {})
    req = builder.build(:get, "http://example.com/path")

    assert_nil req.uri.query
  end

  def test_merge_query_params_when_params_has_values_and_no_query_sets_query
    builder = build_builder(params: { "a" => "1" })
    req = builder.build(:get, "http://example.com/path")

    assert_equal "a=1", req.uri.query
  end

  def test_merge_query_params_when_params_has_values_and_existing_query_concatenates
    builder = build_builder(params: { "b" => "2" })
    req = builder.build(:get, "http://example.com/path?a=1")

    assert_equal "a=1&b=2", req.uri.query
  end

  # empty path normalization (via #build)

  def test_empty_path_normalization_normalizes_to_slash
    builder = build_builder
    req = builder.build(:get, "http://example.com")

    assert_equal "/", req.uri.path
  end

  def test_empty_path_normalization_returns_http_uri_with_corrected_path
    builder = build_builder
    req = builder.build(:get, "http://example.com")

    assert_instance_of HTTP::URI, req.uri
    assert_equal "/", req.uri.path
  end

  # resolve_against_base error handling (via #build)

  def test_resolve_against_base_raises_http_error
    opts = HTTP::Options.new(base_uri: "http://example.com/")
    b = HTTP::Request::Builder.new(opts)
    opts.define_singleton_method(:base_uri) { nil }
    opts.define_singleton_method(:base_uri?) { true }

    err = assert_raises(HTTP::Error) { b.build(:get, "relative") }
    assert_equal "base_uri is not set", err.message
  end

  # make_request_uri scheme guard with base_uri

  def test_scheme_guard_with_base_uri_and_absolute_http_uses_absolute_uri
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "http://other.com/path")

    assert_equal "other.com", req.uri.host
    assert_equal "/path", req.uri.path
  end

  def test_scheme_guard_with_base_uri_and_absolute_https_uses_absolute_uri
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "https://secure.com/path")

    assert_equal "secure.com", req.uri.host
    assert_equal "/path", req.uri.path
  end

  def test_scheme_guard_with_base_uri_and_relative_uri_resolves_against_base
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "users/1")

    assert_equal "example.com", req.uri.host
    assert_equal "/api/users/1", req.uri.path
  end

  # make_request_uri persistent guard

  def test_persistent_guard_when_not_persistent_does_not_prepend_origin
    builder = build_builder
    req = builder.build(:get, "http://example.com/path")

    assert_equal "example.com", req.uri.host
    assert_equal "/path", req.uri.path
  end

  def test_persistent_guard_when_persistent_and_absolute_http_does_not_prepend
    builder = build_builder(persistent: "http://example.com")
    req = builder.build(:get, "http://other.com/path")

    assert_equal "other.com", req.uri.host
  end

  # make_request_uri returns HTTP::URI

  def test_make_request_uri_returns_http_uri_not_stdlib_uri
    builder = build_builder
    req = builder.build(:get, "http://example.com/path")

    assert_instance_of HTTP::URI, req.uri
  end

  # make_request_uri empty path normalization

  def test_make_request_uri_normalizes_empty_path_to_slash_for_bare_domain
    builder = build_builder
    req = builder.build(:get, "http://example.com")

    assert_equal "/", req.uri.path
  end

  def test_make_request_uri_does_not_change_non_empty_path
    builder = build_builder
    req = builder.build(:get, "http://example.com/existing")

    assert_equal "/existing", req.uri.path
  end

  def test_make_request_uri_normalizes_empty_path_when_using_persistent
    opts = HTTP::Options.new(persistent: "http://example.com")
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:get, "http://example.com")

    assert_equal "/", req.uri.path
  end

  # resolve_against_base String conversion

  def test_resolve_against_base_string_conversion_resolves_and_returns_valid_uri
    builder = build_builder(base_uri: "http://example.com/api/")
    req = builder.build(:get, "users")

    assert_instance_of HTTP::URI, req.uri
    assert_equal "/api/users", req.uri.path
    assert_equal "example.com", req.uri.host
  end

  # #build uses HTTP::Request (not Request)

  def test_build_creates_an_http_request_instance
    builder = build_builder
    req = builder.build(:get, "http://example.com/")

    assert_instance_of HTTP::Request, req
  end

  # make_form_data type checks

  def test_make_form_data_with_multipart_subclass_passes_through
    multipart = HTTP::FormData::Multipart.new({ "part" => HTTP::FormData::Part.new("val") })
    opts = HTTP::Options.new(form: multipart)
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:post, "http://example.com/")

    assert_match(%r{\Amultipart/form-data}, req.headers["Content-Type"])
  end

  def test_make_form_data_with_urlencoded_subclass_passes_through
    urlencoded = HTTP::FormData::Urlencoded.new({ "a" => "1" })
    opts = HTTP::Options.new(form: urlencoded)
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:post, "http://example.com/")

    assert_equal "application/x-www-form-urlencoded", req.headers["Content-Type"]
  end

  def test_make_form_data_with_plain_hash_creates_form_data_and_sets_content_type
    opts = HTTP::Options.new(form: { "key" => "value" })
    b = HTTP::Request::Builder.new(opts)
    req = b.build(:post, "http://example.com/")

    assert_equal "application/x-www-form-urlencoded", req.headers["Content-Type"]
    chunks = req.body.enum_for(:each).map(&:dup)

    assert_includes chunks.join, "key=value"
  end
end
