# frozen_string_literal: true

require "test_helper"

class HTTPOptionsTest < Minitest::Test
  cover "HTTP::Options*"

  # .new

  def test_new_returns_the_same_instance_when_given_an_options_object
    original = HTTP::Options.new
    result = HTTP::Options.new(original)

    assert_same original, result
  end

  def test_new_does_not_treat_a_hash_as_an_options_instance
    result = HTTP::Options.new(response: :body)

    assert_instance_of HTTP::Options, result
  end

  def test_new_creates_from_a_hash_argument
    result = HTTP::Options.new(response: :body)

    assert_equal :body, result.response
  end

  def test_new_creates_from_keyword_arguments
    result = HTTP::Options.new(response: :object)

    assert_equal :object, result.response
  end

  def test_new_prefers_positional_hash_over_kwargs
    result = HTTP::Options.new({ response: :body })

    assert_equal :body, result.response
  end

  # .defined_options

  def test_defined_options_returns_an_array
    assert_kind_of Array, HTTP::Options.defined_options
  end

  def test_defined_options_contains_all_expected_option_names_as_symbols
    expected = %i[
      headers encoding features proxy params form json body response
      socket_class nodelay ssl_socket_class ssl_context ssl
      keep_alive_timeout timeout_class timeout_options
      follow retriable base_uri persistent
    ]

    expected.each do |name|
      assert_includes HTTP::Options.defined_options, name
    end
  end

  # .register_feature

  def test_register_feature_stores_the_feature_implementation_by_name
    fake_feature = Class.new(HTTP::Feature)
    HTTP::Options.register_feature(:test_feature_register, fake_feature)

    assert_equal fake_feature, HTTP::Options.available_features[:test_feature_register]
  ensure
    HTTP::Options.available_features.delete(:test_feature_register)
  end

  # #initialize defaults

  def test_initialize_defaults_response_to_auto
    opts = HTTP::Options.new

    assert_equal :auto, opts.response
  end

  def test_initialize_defaults_keep_alive_timeout_to_5
    opts = HTTP::Options.new

    assert_equal 5, opts.keep_alive_timeout
  end

  def test_initialize_defaults_nodelay_to_false
    opts = HTTP::Options.new

    refute opts.nodelay
  end

  def test_initialize_defaults_headers_to_empty
    opts = HTTP::Options.new

    assert_empty opts.headers
  end

  def test_initialize_defaults_ssl_to_empty_hash
    opts = HTTP::Options.new

    assert_equal({}, opts.ssl)
  end

  def test_initialize_defaults_timeout_options_to_empty_hash
    opts = HTTP::Options.new

    assert_equal({}, opts.timeout_options)
  end

  def test_initialize_defaults_proxy_to_empty_hash
    opts = HTTP::Options.new

    assert_equal({}, opts.proxy)
  end

  def test_initialize_defaults_features_to_empty_hash
    opts = HTTP::Options.new

    assert_equal({}, opts.features)
  end

  def test_initialize_defaults_timeout_class_to_timeout_null
    opts = HTTP::Options.new

    assert_equal HTTP::Timeout::Null, opts.timeout_class
  end

  def test_initialize_defaults_socket_class_to_tcpsocket
    opts = HTTP::Options.new

    assert_equal TCPSocket, opts.socket_class
  end

  def test_initialize_defaults_ssl_socket_class_to_openssl_ssl_sslsocket
    opts = HTTP::Options.new

    assert_equal OpenSSL::SSL::SSLSocket, opts.ssl_socket_class
  end

  def test_initialize_defaults_encoding_to_nil
    opts = HTTP::Options.new

    assert_nil opts.encoding
  end

  def test_initialize_defaults_params_to_nil
    opts = HTTP::Options.new

    assert_nil opts.params
  end

  def test_initialize_defaults_form_to_nil
    opts = HTTP::Options.new

    assert_nil opts.form
  end

  def test_initialize_defaults_json_to_nil
    opts = HTTP::Options.new

    assert_nil opts.json
  end

  def test_initialize_defaults_body_to_nil
    opts = HTTP::Options.new

    assert_nil opts.body
  end

  def test_initialize_defaults_follow_to_nil
    opts = HTTP::Options.new

    assert_nil opts.follow
  end

  def test_initialize_defaults_retriable_to_nil
    opts = HTTP::Options.new

    assert_nil opts.retriable
  end

  def test_initialize_defaults_base_uri_to_nil
    opts = HTTP::Options.new

    assert_nil opts.base_uri
  end

  def test_initialize_defaults_persistent_to_nil
    opts = HTTP::Options.new

    assert_nil opts.persistent
  end

  def test_initialize_defaults_ssl_context_to_nil
    opts = HTTP::Options.new

    assert_nil opts.ssl_context
  end

  # #to_hash

  def test_to_hash_contains_all_defined_options
    opts = HTTP::Options.new
    hash = opts.to_hash

    HTTP::Options.defined_options.each do |name|
      assert_includes hash.keys, name
    end
  end

  def test_to_hash_returns_correct_values_for_custom_options
    custom = HTTP::Options.new(response: :body, keep_alive_timeout: 10)
    hash = custom.to_hash

    assert_equal :body, hash[:response]
    assert_equal 10, hash[:keep_alive_timeout]
  end

  # #merge

  def test_merge_merges_headers_by_combining_them
    opts1 = HTTP::Options.new(headers: { foo: "bar" })
    opts2 = HTTP::Options.new(headers: { baz: "qux" })
    merged = opts1.merge(opts2)

    assert_equal "bar", merged.headers["Foo"]
    assert_equal "qux", merged.headers["Baz"]
  end

  def test_merge_replaces_non_header_values
    opts1 = HTTP::Options.new(response: :auto)
    merged = opts1.merge(response: :body)

    assert_equal :body, merged.response
  end

  # #dup

  def test_dup_returns_a_duplicate
    opts = HTTP::Options.new
    dupped = opts.dup

    assert_equal :auto, dupped.response
  end

  def test_dup_yields_the_duplicate_when_a_block_is_given
    opts = HTTP::Options.new
    yielded = nil
    dupped = opts.dup { |d| yielded = d }

    assert_same dupped, yielded
  end

  # #feature

  def test_feature_returns_nil_for_unregistered_feature
    opts = HTTP::Options.new

    assert_nil opts.feature(:nonexistent)
  end

  def test_feature_returns_the_feature_instance_for_a_registered_feature
    opts = HTTP::Options.new
    opts_with = opts.with_features([:auto_inflate])

    assert_instance_of HTTP::Features::AutoInflate, opts_with.feature(:auto_inflate)
  end

  # #with_follow

  def test_with_follow_sets_follow_to_empty_hash_when_true
    opts = HTTP::Options.new
    result = opts.with_follow(true)

    assert_equal({}, result.follow)
  end

  def test_with_follow_sets_follow_to_nil_when_false
    opts = HTTP::Options.new
    result = opts.with_follow(false)

    assert_nil result.follow
  end

  def test_with_follow_sets_follow_to_nil_when_nil
    opts = HTTP::Options.new
    result = opts.with_follow(nil)

    assert_nil result.follow
  end

  def test_with_follow_passes_through_hash_options
    opts = HTTP::Options.new
    result = opts.with_follow(max_hops: 5)

    assert_equal({ max_hops: 5 }, result.follow)
  end

  def test_with_follow_raises_error_for_unsupported_follow_value
    opts = HTTP::Options.new
    err = assert_raises(HTTP::Error) { opts.with_follow(42) }

    assert_match(/Unsupported follow/, err.message)
    assert_includes err.message, "42"
  end

  def test_with_follow_does_not_modify_original
    opts = HTTP::Options.new
    opts.with_follow(true)

    assert_nil opts.follow
  end

  # #with_retriable

  def test_with_retriable_sets_retriable_to_empty_hash_when_true
    opts = HTTP::Options.new
    result = opts.with_retriable(true)

    assert_equal({}, result.retriable)
  end

  def test_with_retriable_sets_retriable_to_nil_when_false
    opts = HTTP::Options.new
    result = opts.with_retriable(false)

    assert_nil result.retriable
  end

  def test_with_retriable_sets_retriable_to_nil_when_nil
    opts = HTTP::Options.new
    result = opts.with_retriable(nil)

    assert_nil result.retriable
  end

  def test_with_retriable_passes_through_hash_options
    opts = HTTP::Options.new
    result = opts.with_retriable(max_retries: 3)

    assert_equal({ max_retries: 3 }, result.retriable)
  end

  def test_with_retriable_raises_error_for_unsupported_retriable_value
    opts = HTTP::Options.new
    err = assert_raises(HTTP::Error) { opts.with_retriable(42) }

    assert_match(/Unsupported retriable/, err.message)
    assert_includes err.message, "42"
  end

  def test_with_retriable_does_not_modify_original
    opts = HTTP::Options.new
    opts.with_retriable(true)

    assert_nil opts.retriable
  end

  # #persistent?

  def test_persistent_returns_false_by_default
    opts = HTTP::Options.new

    refute_predicate opts, :persistent?
  end

  def test_persistent_returns_true_when_persistent_is_set
    opts = HTTP::Options.new
    result = opts.with_persistent("https://example.com")

    assert_predicate result, :persistent?
  end

  # #with_persistent

  def test_with_persistent_sets_persistent_to_origin
    opts = HTTP::Options.new
    result = opts.with_persistent("https://example.com/path")

    assert_equal "https://example.com", result.persistent
  end

  def test_with_persistent_clears_persistent_when_set_to_nil
    opts = HTTP::Options.new
    with_persistent = opts.with_persistent("https://example.com")
    result = with_persistent.with_persistent(nil)

    assert_nil result.persistent
  end

  # #with_encoding

  def test_with_encoding_finds_encoding_by_name
    opts = HTTP::Options.new
    result = opts.with_encoding("UTF-8")

    assert_equal Encoding::UTF_8, result.encoding
  end

  # #features=

  def test_features_accepts_pre_built_feature_instances
    feature_instance = HTTP::Features::AutoInflate.new
    result = HTTP::Options.new(features: { auto_inflate: feature_instance })

    assert_same feature_instance, result.features[:auto_inflate]
  end

  def test_features_raises_for_unsupported_feature_names
    err = assert_raises(HTTP::Error) { HTTP::Options.new(features: { bogus: {} }) }

    assert_equal "Unsupported feature: bogus", err.message
  end

  # with_ methods for simple options

  def test_with_proxy_returns_new_options_with_updated_proxy
    opts = HTTP::Options.new
    result = opts.with_proxy(proxy_address: "127.0.0.1")

    assert_equal({ proxy_address: "127.0.0.1" }, result.proxy)
    assert_equal({}, opts.proxy)
  end

  def test_with_params_returns_new_options_with_updated_params
    opts = HTTP::Options.new
    result = opts.with_params(foo: "bar")

    assert_equal({ foo: "bar" }, result.params)
    assert_nil opts.params
  end

  def test_with_form_returns_new_options_with_updated_form
    opts = HTTP::Options.new
    result = opts.with_form(foo: 42)

    assert_equal({ foo: 42 }, result.form)
    assert_nil opts.form
  end

  def test_with_json_returns_new_options_with_updated_json
    opts = HTTP::Options.new
    result = opts.with_json(foo: 42)

    assert_equal({ foo: 42 }, result.json)
    assert_nil opts.json
  end

  def test_with_body_returns_new_options_with_updated_body
    opts = HTTP::Options.new
    result = opts.with_body("data")

    assert_equal "data", result.body
    assert_nil opts.body
  end

  def test_with_response_returns_new_options_with_updated_response
    opts = HTTP::Options.new
    result = opts.with_response(:body)

    assert_equal :body, result.response
    assert_equal :auto, opts.response
  end

  def test_with_socket_class_returns_new_options
    opts = HTTP::Options.new
    custom_class = Class.new
    result = opts.with_socket_class(custom_class)

    assert_equal custom_class, result.socket_class
  end

  def test_with_nodelay_returns_new_options
    opts = HTTP::Options.new
    result = opts.with_nodelay(true)

    assert result.nodelay
  end

  def test_with_ssl_socket_class_returns_new_options
    opts = HTTP::Options.new
    custom_class = Class.new
    result = opts.with_ssl_socket_class(custom_class)

    assert_equal custom_class, result.ssl_socket_class
  end

  def test_with_ssl_context_returns_new_options
    opts = HTTP::Options.new
    ctx = OpenSSL::SSL::SSLContext.new
    result = opts.with_ssl_context(ctx)

    assert_equal ctx, result.ssl_context
  end

  def test_with_ssl_returns_new_options
    opts = HTTP::Options.new
    result = opts.with_ssl(verify_mode: OpenSSL::SSL::VERIFY_NONE)

    assert_equal({ verify_mode: OpenSSL::SSL::VERIFY_NONE }, result.ssl)
  end

  def test_with_keep_alive_timeout_returns_new_options
    opts = HTTP::Options.new
    result = opts.with_keep_alive_timeout(10)

    assert_equal 10, result.keep_alive_timeout
  end

  def test_with_timeout_class_returns_new_options
    opts = HTTP::Options.new
    custom_class = Class.new
    result = opts.with_timeout_class(custom_class)

    assert_equal custom_class, result.timeout_class
  end

  def test_with_timeout_options_returns_new_options
    opts = HTTP::Options.new
    result = opts.with_timeout_options(read_timeout: 5)

    assert_equal({ read_timeout: 5 }, result.timeout_options)
  end

  # #argument_error! backtrace

  def test_argument_error_excludes_argument_error_from_the_backtrace
    opts = HTTP::Options.new
    err = assert_raises(HTTP::Error) { opts.with_follow(42) }

    refute err.backtrace.any? { |line| line.include?("argument_error!") },
           "backtrace should not include argument_error! method"
  end

  def test_argument_error_starts_the_backtrace_at_the_calling_setter_method
    opts = HTTP::Options.new
    err = assert_raises(HTTP::Error) { opts.with_follow(42) }

    assert_includes err.backtrace.first, "definitions.rb"
  end

  def test_argument_error_includes_more_than_one_backtrace_frame
    opts = HTTP::Options.new
    err = assert_raises(HTTP::Error) { opts.with_follow(42) }

    assert_operator err.backtrace.length, :>, 1
  end

  def test_argument_error_preserves_the_full_backtrace_down_to_the_bottom_of_the_stack
    opts = HTTP::Options.new
    ref_err = begin; raise HTTP::Error, "ref"; rescue HTTP::Error => e; e; end
    arg_err = assert_raises(HTTP::Error) { opts.with_follow(42) }

    assert_equal ref_err.backtrace.last, arg_err.backtrace.last
  end

  # non-reader_only options have protected writers

  def test_response_writer_is_protected
    opts = HTTP::Options.new

    assert_raises(NoMethodError) { opts.response = :body }
  end

  def test_proxy_writer_is_protected
    opts = HTTP::Options.new

    assert_raises(NoMethodError) { opts.proxy = {} }
  end

  def test_keep_alive_timeout_writer_is_protected
    opts = HTTP::Options.new

    assert_raises(NoMethodError) { opts.keep_alive_timeout = 10 }
  end
end
