# frozen_string_literal: true

require "test_helper"

require "json"

require "support/dummy_server"
require "support/proxy_server"

class HTTPTest < Minitest::Test
  cover "HTTP::Chainable*"
  run_server(:dummy) { DummyServer.new }
  run_server(:dummy_ssl) { DummyServer.new(ssl: true) }

  # getting resources

  def test_getting_resources_is_easy
    response = HTTP.get dummy.endpoint

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_getting_resources_with_uri_instance
    response = HTTP.get HTTP::URI.parse(dummy.endpoint)

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_getting_resources_with_query_string_parameters
    response = HTTP.get "#{dummy.endpoint}/params", params: { foo: "bar" }

    assert_match(/Params!/, response.to_s)
  end

  def test_getting_resources_with_query_string_parameters_in_uri_and_opts
    response = HTTP.get "#{dummy.endpoint}/multiple-params?foo=bar", params: { baz: "quux" }

    assert_match(/More Params!/, response.to_s)
  end

  def test_getting_resources_with_two_leading_slashes_in_path
    HTTP.get "#{dummy.endpoint}//"
  end

  def test_getting_resources_with_headers
    response = HTTP.accept("application/json").get dummy.endpoint

    assert_includes response.to_s, "json"
  end

  # getting resources with a large request body + timeout variants

  [:null, 6, { read: 2, write: 2, connect: 2 }, { global: 6, read: 2, write: 2, connect: 2 }].each do |timeout|
    define_method :"test_large_request_body_with_timeout_#{timeout.inspect}" do
      request_body = "\xE2\x80\x9C" * 1_000_000
      client = HTTP.timeout(timeout)
      response = client.post "#{dummy.endpoint}/echo-body", body: request_body

      assert_equal request_body.b, response.body.to_s
      assert_equal request_body.bytesize, response.headers["Content-Length"].to_i
    end
  end

  # with a block

  def test_block_yields_the_response
    HTTP.get(dummy.endpoint) do |response|
      assert_match(/<!doctype html>/, response.to_s)
    end
  end

  def test_block_returns_the_block_value
    result = HTTP.get(dummy.endpoint) { |response| response.status.code }

    assert_equal 200, result
  end

  def test_block_closes_the_connection_after_the_block
    client = nil
    HTTP.stub(:make_client, lambda { |opts|
      client = HTTP::Client.new(opts)
      original_close = client.method(:close)
      client.define_singleton_method(:close) do
        @test_closed = true
        original_close.call
      end
      client.define_singleton_method(:test_closed?) { @test_closed == true }
      client
    }) do
      HTTP.get(dummy.endpoint, &:status)
    end

    assert_predicate client, :test_closed?, "expected close to have been called"
  end

  def test_block_closes_the_connection_even_when_the_block_raises
    client = nil

    HTTP.stub(:make_client, lambda { |opts|
      client = HTTP::Client.new(opts)
      original_close = client.method(:close)
      client.define_singleton_method(:close) do
        @test_closed = true
        original_close.call
      end
      client.define_singleton_method(:test_closed?) { @test_closed == true }
      client
    }) do
      assert_raises(RuntimeError) do
        HTTP.get(dummy.endpoint) { raise "boom" }
      end
    end

    assert_predicate client, :test_closed?, "expected close to have been called on error"
  end

  def test_block_works_with_chained_options
    result = HTTP.headers("Accept" => "application/json").get(dummy.endpoint) do |response|
      response.status.code
    end

    assert_equal 200, result
  end

  def test_block_handles_nil_client_when_make_client_raises
    HTTP.stub(:make_client, ->(*) { raise "boom" }) do
      assert_raises(RuntimeError) { HTTP.get(dummy.endpoint) { nil } }
    end
  end

  # .retry

  def test_retry_ensures_endpoint_counts_retries
    assert_equal "retried 1x", HTTP.get("#{dummy.endpoint}/retry-2").to_s
    assert_equal "retried 2x", HTTP.get("#{dummy.endpoint}/retry-2").to_s
  end

  def test_retry_retries_the_request
    response = HTTP.retriable(delay: 0, retry_statuses: 500...600).get "#{dummy.endpoint}/retry-2"

    assert_equal "retried 2x", response.to_s
  end

  def test_retry_retries_the_request_and_gives_access_to_failed_requests
    err = nil
    retry_callback = ->(_, _, res) { assert_match(/^retried \dx$/, res.to_s) }
    begin
      HTTP.retriable(
        should_retry: ->(*) { true },
        tries:        3,
        delay:        0,
        on_retry:     retry_callback
      ).get "#{dummy.endpoint}/retry-2"
    rescue HTTP::Error => e
      err = e
    end

    assert_equal "retried 3x", err.response.to_s
  end

  # posting forms to resources

  def test_posting_forms_is_easy
    response = HTTP.post "#{dummy.endpoint}/form", form: { example: "testing-form" }

    assert_equal "passed :)", response.to_s
  end

  # loading binary data

  def test_binary_data_is_encoded_as_bytes
    response = HTTP.get "#{dummy.endpoint}/bytes"

    assert_equal Encoding::BINARY, response.to_s.encoding
  end

  # loading endpoint with charset

  def test_charset_uses_charset_from_headers
    response = HTTP.get "#{dummy.endpoint}/iso-8859-1"

    assert_equal Encoding::ISO8859_1, response.to_s.encoding
    assert_equal "testæ", response.to_s.encode(Encoding::UTF_8)
  end

  def test_charset_with_encoding_option_respects_option
    response = HTTP.get "#{dummy.endpoint}/iso-8859-1", encoding: Encoding::BINARY

    assert_equal Encoding::BINARY, response.to_s.encoding
  end

  # passing a string encoding type

  def test_string_encoding_type_finds_encoding
    response = HTTP.get dummy.endpoint, encoding: "ascii"

    assert_equal Encoding::ASCII, response.to_s.encoding
  end

  # loading text with no charset

  def test_text_with_no_charset_is_binary_encoded
    response = HTTP.get dummy.endpoint

    assert_equal Encoding::BINARY, response.to_s.encoding
  end

  # posting with an explicit body

  def test_posting_with_explicit_body_is_easy
    response = HTTP.post "#{dummy.endpoint}/body", body: "testing-body"

    assert_equal "passed :)", response.to_s
  end

  # with redirects

  def test_redirects_is_easy_for_301
    response = HTTP.follow.get("#{dummy.endpoint}/redirect-301")

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_redirects_is_easy_for_302
    response = HTTP.follow.get("#{dummy.endpoint}/redirect-302")

    assert_match(/<!doctype html>/, response.to_s)
  end

  # head requests

  def test_head_request_is_easy
    response = HTTP.head dummy.endpoint

    assert_equal 200, response.status.to_i
    assert_match(/html/, response.headers["content-type"])
  end

  # .auth

  def test_auth_sets_authorization_header
    client = HTTP.auth "abc"

    assert_equal "abc", client.default_options.headers[:authorization]
  end

  def test_auth_accepts_any_to_s_object
    client = HTTP.auth fake(to_s: "abc")

    assert_equal "abc", client.default_options.headers[:authorization]
  end

  # .basic_auth

  def test_basic_auth_fails_when_pass_is_not_given
    assert_raises(ArgumentError) { HTTP.basic_auth(user: "[USER]") }
  end

  def test_basic_auth_fails_when_user_is_not_given
    assert_raises(ArgumentError) { HTTP.basic_auth(pass: "[PASS]") }
  end

  def test_basic_auth_sets_authorization_header
    client = HTTP.basic_auth user: "foo", pass: "bar"

    assert_match(%r{^Basic [A-Za-z0-9+/]+=*$}, client.default_options.headers[:authorization])
  end

  # .base_uri

  def test_base_uri_resolves_relative_paths
    response = HTTP.base_uri(dummy.endpoint).get("/")

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_base_uri_resolves_paths_without_leading_slash
    response = HTTP.base_uri(dummy.endpoint).get("params?foo=bar")

    assert_match(/Params!/, response.to_s)
  end

  def test_base_uri_ignores_base_uri_for_absolute_urls
    response = HTTP.base_uri("https://other.example.com").get(dummy.endpoint)

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_base_uri_chains_base_uris
    session = HTTP.base_uri("https://example.com").base_uri("api/v1")

    assert_equal "https://example.com/api/v1", session.default_options.base_uri.to_s
  end

  def test_base_uri_works_with_other_chainable_methods
    response = HTTP.base_uri(dummy.endpoint)
                   .headers("Accept" => "application/json")
                   .get("/")

    assert_includes response.to_s, "json"
  end

  def test_base_uri_raises_for_uri_without_scheme
    assert_raises(HTTP::Error) { HTTP.base_uri("/users") }
  end

  def test_base_uri_derives_persistent_host_from_base_uri
    p_client = HTTP.base_uri(dummy.endpoint).persistent

    assert_predicate p_client, :persistent?
  ensure
    p_client&.close
  end

  def test_base_uri_raises_when_persistent_host_not_given_and_no_base_uri
    assert_raises(ArgumentError) { HTTP.persistent }
  end

  # .persistent

  def test_persistent_with_host_returns_http_session
    persistent_client = HTTP.persistent dummy.endpoint

    assert_kind_of HTTP::Session, persistent_client
  end

  def test_persistent_with_host_is_persistent
    persistent_client = HTTP.persistent dummy.endpoint

    assert_predicate persistent_client, :persistent?
  end

  def test_persistent_with_block_returns_last_expression
    assert_equal :http, HTTP.persistent(dummy.endpoint) { :http }
  end

  def test_persistent_with_block_auto_closes_connection
    closed = false
    HTTP.persistent dummy.endpoint do |session|
      original_close = session.method(:close)
      session.define_singleton_method(:close) do
        closed = true
        original_close.call
      end
      session.get("/")
    end

    assert closed, "expected close to have been called"
  end

  def test_persistent_when_initialization_raises_handles_nil_session
    opts = HTTP.default_options

    opts.stub(:merge, ->(*) { raise "boom" }) do
      assert_raises(RuntimeError) { HTTP.persistent(dummy.endpoint) { nil } }
    end
  end

  def test_persistent_with_timeout_sets_keep_alive_timeout
    persistent_client = HTTP.persistent dummy.endpoint, timeout: 100
    options = persistent_client.default_options

    assert_equal 100, options.keep_alive_timeout
  end

  # .timeout

  def test_timeout_null_sets_timeout_class_to_null
    client = HTTP.timeout :null

    assert_equal HTTP::Timeout::Null, client.default_options.timeout_class
  end

  def test_timeout_per_operation_sets_timeout_class
    client = HTTP.timeout read: 123

    assert_equal HTTP::Timeout::PerOperation, client.default_options.timeout_class
  end

  def test_timeout_per_operation_sets_timeout_options
    client = HTTP.timeout read: 123

    assert_equal({ read_timeout: 123 }, client.default_options.timeout_options)
  end

  def test_timeout_per_operation_long_form_keys
    client = HTTP.timeout read_timeout: 123

    assert_equal({ read_timeout: 123 }, client.default_options.timeout_options)
  end

  def test_timeout_all_per_operation_sets_all_options
    client = HTTP.timeout read: 1, write: 2, connect: 3

    assert_equal({ read_timeout: 1, write_timeout: 2, connect_timeout: 3 }, client.default_options.timeout_options)
  end

  def test_timeout_per_operation_frozen_hash_does_not_raise
    frozen_options = { read: 123 }.freeze
    HTTP.timeout(frozen_options)
  end

  def test_timeout_empty_hash_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout({}) }
  end

  def test_timeout_unknown_key_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout(timeout: 2) }
  end

  def test_timeout_both_short_and_long_form_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout(read: 2, read_timeout: 2) }
  end

  def test_timeout_non_numeric_value_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout(read: "2") }
  end

  def test_timeout_string_keys_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout("read" => 2) }
  end

  def test_timeout_global_as_hash_key_sets_timeout_class
    client = HTTP.timeout global: 60

    assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
  end

  def test_timeout_global_as_hash_key_sets_timeout_option
    client = HTTP.timeout global: 60

    assert_equal({ global_timeout: 60 }, client.default_options.timeout_options)
  end

  def test_timeout_global_long_form_sets_timeout_class
    client = HTTP.timeout global_timeout: 60

    assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
  end

  def test_timeout_global_long_form_sets_timeout_option
    client = HTTP.timeout global_timeout: 60

    assert_equal({ global_timeout: 60 }, client.default_options.timeout_options)
  end

  def test_timeout_combined_global_and_per_operation_sets_timeout_class
    client = HTTP.timeout global: 60, read: 30, write: 20, connect: 5

    assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
  end

  def test_timeout_combined_global_and_per_operation_sets_all_options
    client = HTTP.timeout global: 60, read: 30, write: 20, connect: 5
    expected = { read_timeout: 30, write_timeout: 20, connect_timeout: 5, global_timeout: 60 }

    assert_equal expected, client.default_options.timeout_options
  end

  def test_timeout_combined_global_and_partial_per_operation_sets_timeout_class
    client = HTTP.timeout global: 60, read: 30

    assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
  end

  def test_timeout_combined_global_and_partial_per_operation_includes_both
    client = HTTP.timeout global: 60, read: 30
    expected = { read_timeout: 30, global_timeout: 60 }

    assert_equal expected, client.default_options.timeout_options
  end

  def test_timeout_both_short_and_long_form_of_global_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout(global: 60, global_timeout: 60) }
  end

  def test_timeout_non_numeric_global_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout(global: "60") }
  end

  def test_timeout_global_numeric_sets_timeout_class
    client = HTTP.timeout 123

    assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
  end

  def test_timeout_global_numeric_sets_timeout_option
    client = HTTP.timeout 123

    assert_equal({ global_timeout: 123 }, client.default_options.timeout_options)
  end

  def test_timeout_float_global_sets_timeout_option
    client = HTTP.timeout 2.5

    assert_equal({ global_timeout: 2.5 }, client.default_options.timeout_options)
  end

  def test_timeout_unsupported_options_raises_argument_error
    assert_raises(ArgumentError) { HTTP.timeout("invalid") }
  end

  # .cookies

  def test_cookies_passes_correct_cookie_header
    endpoint = "#{dummy.endpoint}/cookies"

    assert_equal "abc: def", HTTP.cookies(abc: :def).get(endpoint).to_s
  end

  def test_cookies_properly_works_with_cookies_from_response
    endpoint = "#{dummy.endpoint}/cookies"
    res = HTTP.get(endpoint).flush

    assert_equal "foo: bar", HTTP.cookies(res.cookies).get(endpoint).to_s
  end

  def test_cookies_replaces_previously_set_cookies
    endpoint = "#{dummy.endpoint}/cookies"
    client = HTTP.cookies(foo: 123, bar: 321).cookies(baz: :moo)

    assert_equal "baz: moo", client.get(endpoint).to_s
  end

  # .nodelay

  def test_nodelay_sets_tcp_nodelay_on_underlying_socket
    socket_spy_class = Class.new(TCPSocket) do
      def self.setsockopt_calls
        @setsockopt_calls ||= []
      end

      def setsockopt(*args)
        self.class.setsockopt_calls << args
        super
      end
    end

    HTTP.default_options = { socket_class: socket_spy_class }

    HTTP.get(dummy.endpoint)

    assert_equal [], socket_spy_class.setsockopt_calls
    HTTP.nodelay.get(dummy.endpoint)

    assert_equal [[Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1]], socket_spy_class.setsockopt_calls
  ensure
    HTTP.default_options = {}
  end

  # .use

  def test_use_turns_on_given_feature
    client = HTTP.use :auto_deflate

    assert_equal [:auto_deflate], client.default_options.features.keys
  end

  def test_use_auto_deflate_sends_gzipped_body
    client   = HTTP.use :auto_deflate
    body     = "Hello!"
    response = client.post("#{dummy.endpoint}/echo-body", body: body)
    encoded  = response.to_s

    assert_equal body, Zlib::GzipReader.new(StringIO.new(encoded)).read
  end

  def test_use_auto_deflate_sends_deflated_body
    client   = HTTP.use auto_deflate: { method: "deflate" }
    body     = "Hello!"
    response = client.post("#{dummy.endpoint}/echo-body", body: body)
    encoded  = response.to_s

    assert_equal body, Zlib::Inflate.inflate(encoded)
  end

  def test_use_auto_inflate_returns_raw_body_when_content_encoding_missing
    client   = HTTP.use :auto_inflate
    body     = "Hello!"
    response = client.post("#{dummy.endpoint}/encoded-body", body: body)

    assert_equal "#{body}-raw", response.to_s
  end

  def test_use_auto_inflate_returns_decoded_body
    client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "gzip")
    body     = "Hello!"
    response = client.post("#{dummy.endpoint}/encoded-body", body: body)

    assert_equal "#{body}-gzipped", response.to_s
  end

  def test_use_auto_inflate_returns_deflated_body
    client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "deflate")
    body     = "Hello!"
    response = client.post("#{dummy.endpoint}/encoded-body", body: body)

    assert_equal "#{body}-deflated", response.to_s
  end

  def test_use_auto_inflate_returns_empty_body_for_204_with_gzip
    client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "gzip")
    body     = "Hello!"
    response = client.post("#{dummy.endpoint}/no-content-204", body: body)

    assert_equal "", response.to_s
  end

  def test_use_auto_inflate_returns_empty_body_for_204_with_deflate
    client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "deflate")
    body     = "Hello!"
    response = client.post("#{dummy.endpoint}/no-content-204", body: body)

    assert_equal "", response.to_s
  end

  def test_use_normalize_uri_normalizes_uri
    response = HTTP.get "#{dummy.endpoint}/héllö-wörld"

    assert_equal "hello world", response.to_s
  end

  def test_use_normalize_uri_uses_custom_normalizer
    client = HTTP.use(normalize_uri: { normalizer: :itself.to_proc })
    response = client.get("#{dummy.endpoint}/héllö-wörld")

    assert_equal 400, response.status.to_i
  end

  def test_use_normalize_uri_raises_if_custom_normalizer_returns_invalid_path
    client = HTTP.use(normalize_uri: { normalizer: :itself.to_proc })
    err = assert_raises(HTTP::RequestError) { client.get("#{dummy.endpoint}/hello\nworld") }
    assert_equal 'Invalid request URI: "/hello\nworld"', err.message
  end

  def test_use_normalize_uri_raises_if_custom_normalizer_returns_invalid_host
    normalizer = lambda do |uri|
      uri.instance_variable_set(:@host, "example\ncom")
      uri
    end
    client = HTTP.use(normalize_uri: { normalizer: normalizer })
    err = assert_raises(HTTP::RequestError) { client.get(dummy.endpoint) }
    assert_match(/Invalid host: "example\\ncom/, err.message)
  end

  def test_use_normalize_uri_uses_default_normalizer
    client = HTTP.use :normalize_uri
    response = client.get("#{dummy.endpoint}/héllö-wörld")

    assert_equal "hello world", response.to_s
  end

  # dynamic verb tests

  %i[put delete trace options connect patch].each do |verb|
    define_method :"test_#{verb}_delegates_to_request" do
      mock_client = Minitest::Mock.new
      mock_client.expect(:request, nil, [verb, "http://example.com/"])
      HTTP::Client.stub(:new, mock_client) do
        HTTP.public_send(verb, "http://example.com/")
      end
      mock_client.verify
    end
  end

  # Request::Builder

  def test_request_builder_builds_http_request_from_options
    options = HTTP::Options.new
    builder = HTTP::Request::Builder.new(options)
    req = builder.build(:get, "http://example.com/")

    assert_kind_of HTTP::Request, req
  end

  # .encoding

  def test_encoding_returns_session_with_specified_encoding
    session = HTTP::Client.new.encoding("UTF-8")

    assert_kind_of HTTP::Session, session
  end

  # .via - proxy_headers tests (no actual proxy server needed)

  def test_via_with_proxy_headers_as_third_argument
    client = HTTP.via("proxy.example.com", 8080, { "X-Custom" => "val" })
    proxy = client.default_options.proxy

    assert_equal({ "X-Custom" => "val" }, proxy[:proxy_headers])
  end

  def test_via_with_proxy_headers_as_fifth_argument
    hdrs = { "X-Custom" => "val" }
    client = HTTP.via("proxy.example.com", 8080, "user", "pass", hdrs)
    proxy = client.default_options.proxy

    assert_equal({ "X-Custom" => "val" }, proxy[:proxy_headers])
  end

  def test_via_with_non_string_first_argument_skips_proxy_address
    client = HTTP.via(nil, 8080, { "X-Custom" => "val" })
    proxy = client.default_options.proxy

    refute proxy.key?(:proxy_address)
  end

  # socket error unification

  def test_unifies_socket_errors_into_http_connection_error
    original_open = TCPSocket.method(:open)
    stub_open = lambda do |*args|
      raise SocketError if args[0] == "thishostshouldnotexists.com"

      original_open.call(*args)
    end
    TCPSocket.stub(:open, stub_open) do
      assert_raises(HTTP::ConnectionError) { HTTP.get "http://thishostshouldnotexists.com" }
      assert_raises(HTTP::ConnectionError) { HTTP.get "http://127.0.0.1:111" }
    end
  end
end

class HTTPViaAnonymousProxyTest < Minitest::Test
  run_server(:dummy) { DummyServer.new }
  run_server(:dummy_ssl) { DummyServer.new(ssl: true) }
  run_server(:proxy) { ProxyServer.new }

  def ssl_client
    HTTP::Client.new ssl_context: SSLHelper.client_context
  end

  def test_anonymous_proxy_proxies_the_request
    response = HTTP.via(proxy.addr, proxy.port).get dummy.endpoint

    assert_equal "true", response.headers["X-Proxied"]
  end

  def test_anonymous_proxy_responds_with_endpoint_body
    response = HTTP.via(proxy.addr, proxy.port).get dummy.endpoint

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_anonymous_proxy_raises_argument_error_if_no_port_given
    assert_raises(HTTP::RequestError) { HTTP.via(proxy.addr) }
  end

  def test_anonymous_proxy_ignores_credentials
    response = HTTP.via(proxy.addr, proxy.port, "username", "password").get dummy.endpoint

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_anonymous_proxy_ssl_responds_with_endpoint_body
    response = ssl_client.via(proxy.addr, proxy.port).get dummy_ssl.endpoint

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_anonymous_proxy_ssl_ignores_credentials
    response = ssl_client.via(proxy.addr, proxy.port, "username", "password").get dummy_ssl.endpoint

    assert_match(/<!doctype html>/, response.to_s)
  end
end

class HTTPViaAuthProxyTest < Minitest::Test
  run_server(:dummy) { DummyServer.new }
  run_server(:dummy_ssl) { DummyServer.new(ssl: true) }
  run_server(:proxy) { AuthProxyServer.new }

  def ssl_client
    HTTP::Client.new ssl_context: SSLHelper.client_context
  end

  def test_auth_proxy_proxies_the_request
    response = HTTP.via(proxy.addr, proxy.port, "username", "password").get dummy.endpoint

    assert_equal "true", response.headers["X-Proxied"]
  end

  def test_auth_proxy_responds_with_endpoint_body
    response = HTTP.via(proxy.addr, proxy.port, "username", "password").get dummy.endpoint

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_auth_proxy_responds_with_407_when_wrong_credentials
    response = HTTP.via(proxy.addr, proxy.port, "user", "pass").get dummy.endpoint

    assert_equal 407, response.status.to_i
  end

  def test_auth_proxy_responds_with_407_if_no_credentials
    response = HTTP.via(proxy.addr, proxy.port).get dummy.endpoint

    assert_equal 407, response.status.to_i
  end

  def test_auth_proxy_ssl_responds_with_endpoint_body
    response = ssl_client.via(proxy.addr, proxy.port, "username", "password").get dummy_ssl.endpoint

    assert_match(/<!doctype html>/, response.to_s)
  end

  def test_auth_proxy_ssl_responds_with_407_when_wrong_credentials
    response = ssl_client.via(proxy.addr, proxy.port, "user", "pass").get dummy_ssl.endpoint

    assert_equal 407, response.status.to_i
  end

  def test_auth_proxy_ssl_responds_with_407_if_no_credentials
    response = ssl_client.via(proxy.addr, proxy.port).get dummy_ssl.endpoint

    assert_equal 407, response.status.to_i
  end
end
