# frozen_string_literal: true

require "test_helper"

require "support/dummy_server"

class HTTPSessionTest < Minitest::Test
  cover "HTTP::Session*"
  run_server(:dummy) { DummyServer.new }
  run_server(:dummy2) { DummyServer.new }

  def session
    @session ||= HTTP::Session.new
  end

  # #initialize

  def test_initialize_creates_a_session_with_default_options
    assert_kind_of HTTP::Options, session.default_options
  end

  def test_initialize_creates_a_session_with_given_options
    session = HTTP::Session.new(headers: { "Accept" => "text/html" })

    assert_equal "text/html", session.default_options.headers[:accept]
  end

  # #request

  def test_request_returns_an_http_response
    response = session.request(:get, dummy.endpoint)

    assert_kind_of HTTP::Response, response
  end

  def test_request_creates_a_new_client_for_each_request
    client_ids = []
    original_new = HTTP::Client.method(:new)

    HTTP::Client.stub(:new, lambda { |*args|
      c = original_new.call(*args)
      client_ids << c.object_id
      c
    }) do
      session.get(dummy.endpoint)
      session.get(dummy.endpoint)
    end

    assert_equal 2, client_ids.uniq.size
  end

  # #request with block

  def test_request_with_block_yields_the_response_and_returns_block_value
    result = session.get(dummy.endpoint) { |res| res.status.code }

    assert_equal 200, result
  end

  def test_request_with_block_closes_the_client_after_the_block
    closed = false
    original_make = session.method(:make_client) # steep:ignore
    session.define_singleton_method(:make_client) do |opts|
      client = original_make.call(opts)
      original_close = client.method(:close)
      client.define_singleton_method(:close) do
        closed = true
        original_close.call
      end
      client
    end

    session.get(dummy.endpoint, &:status)

    assert closed, "expected close to have been called"
  end

  def test_request_with_block_closes_the_client_even_when_the_block_raises
    closed = false
    original_make = session.method(:make_client) # steep:ignore
    session.define_singleton_method(:make_client) do |opts|
      client = original_make.call(opts)
      original_close = client.method(:close)
      client.define_singleton_method(:close) do
        closed = true
        original_close.call
      end
      client
    end

    assert_raises(RuntimeError) { session.get(dummy.endpoint) { raise "boom" } }

    assert closed, "expected close to have been called on error"
  end

  def test_request_with_block_handles_nil_client_when_make_client_raises
    session.define_singleton_method(:make_client) { |*| raise "boom" }

    assert_raises(RuntimeError) { session.get(dummy.endpoint) { nil } }
  end

  # Request::Builder

  def test_request_builder_builds_an_http_request_from_session_options
    builder = HTTP::Request::Builder.new(session.default_options)
    req = builder.build(:get, "http://example.com/")

    assert_kind_of HTTP::Request, req
  end

  # #persistent?

  def test_persistent_returns_false_by_default
    refute_predicate session, :persistent?
  end

  # chaining

  def test_chaining_returns_a_session_from_headers
    chained = session.headers("Accept" => "text/html")

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_timeout
    chained = session.timeout(10)

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_cookies
    chained = session.cookies(session_id: "abc")

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_follow
    chained = session.follow

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_use
    chained = session.use(:auto_deflate)

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_nodelay
    chained = session.nodelay

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_encoding
    chained = session.encoding("UTF-8")

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_via
    chained = session.via("proxy.example.com", 8080)

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_retriable
    chained = session.retriable

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_returns_a_session_from_digest_auth
    chained = session.digest_auth(user: "admin", pass: "secret")

    assert_kind_of HTTP::Session, chained
  end

  def test_chaining_preserves_options_through_chaining
    chained = session.headers("Accept" => "text/html")
                     .timeout(10)
                     .cookies(session_id: "abc")

    assert_equal "text/html", chained.default_options.headers[:accept]
    assert_equal HTTP::Timeout::Global, chained.default_options.timeout_class
    assert_equal "session_id=abc", chained.default_options.headers["Cookie"]
  end

  # thread safety

  def test_thread_safety_can_be_shared_across_threads_without_errors
    shared_session = HTTP.headers("Accept" => "text/html").timeout(15)
    errors = []
    mutex = Mutex.new

    threads = Array.new(5) do
      Thread.new do
        shared_session.get(dummy.endpoint)
      rescue => e
        mutex.synchronize { errors << e }
      end
    end
    threads.each(&:join)

    assert_empty errors, "Expected no errors but got: #{errors.map(&:message).join(', ')}"
  end

  # cookies during redirects

  def test_cookies_during_redirects_forwards_response_cookies_through_redirect_chain
    response = HTTP.follow.get("#{dummy.endpoint}/redirect-with-cookie")

    assert_includes response.to_s, "from_redirect=yes"
  end

  def test_cookies_during_redirects_accumulates_cookies_across_redirect_hops
    response = HTTP.follow.get("#{dummy.endpoint}/redirect-cookie-chain/1")
    body = response.to_s

    assert_includes body, "first=1"
    assert_includes body, "second=2"
  end

  def test_cookies_during_redirects_forwards_initial_request_cookies_through_redirects
    response = HTTP.cookies(original: "value").follow.get("#{dummy.endpoint}/redirect-no-cookies")

    assert_includes response.to_s, "original=value"
  end

  def test_cookies_during_redirects_deletes_cookies_with_empty_value_during_redirect
    response = HTTP.follow.get("#{dummy.endpoint}/redirect-set-then-delete/1")

    refute_includes response.to_s, "temp="
  end

  def test_cookies_during_redirects_breaks_redirect_loop_when_cookie_changes_the_server_response
    response = HTTP.follow.get("#{dummy.endpoint}/cookie-loop")

    assert_equal "authenticated", response.to_s
  end

  def test_cookies_during_redirects_does_not_set_cookie_header_when_no_cookies_present
    response = HTTP.follow.get("#{dummy.endpoint}/redirect-no-cookies")

    assert_equal "", response.to_s
  end

  def test_cookies_during_redirects_applies_features_to_redirect_requests
    response = HTTP.use(:auto_deflate).follow.get("#{dummy.endpoint}/redirect-301")

    assert_equal "<!doctype html>", response.to_s
  end

  # persistent

  def test_persistent_returns_an_http_session
    session = HTTP::Session.new.persistent(dummy.endpoint)

    assert_kind_of HTTP::Session, session
  ensure
    session&.close
  end

  # #close

  def test_close_closes_all_pooled_clients
    session = HTTP.persistent(dummy.endpoint)
    session.get("/")

    clients = session.instance_variable_get(:@clients)

    refute_empty clients

    session.close

    assert_empty clients
  end

  def test_close_is_safe_to_call_on_non_persistent_sessions
    session.close
  end

  # persistent connection reuse with chaining

  def test_persistent_chaining_reuses_connections_when_chaining_headers
    session = HTTP.persistent(dummy.endpoint)

    sock1 = session.headers("Accept" => "application/json").get("#{dummy.endpoint}/socket/1").to_s
    sock2 = session.headers("Accept" => "text/html").get("#{dummy.endpoint}/socket/2").to_s

    refute_equal "", sock1
    assert_equal sock1, sock2
  ensure
    session&.close
  end

  def test_persistent_chaining_reuses_connections_when_chaining_auth
    session = HTTP.persistent(dummy.endpoint)

    sock1 = session.auth("Bearer token").get("#{dummy.endpoint}/socket/1").to_s
    sock2 = session.auth("Bearer token").get("#{dummy.endpoint}/socket/2").to_s

    refute_equal "", sock1
    assert_equal sock1, sock2
  ensure
    session&.close
  end

  def test_persistent_chaining_shares_the_connection_pool_across_chained_sessions
    session = HTTP.persistent(dummy.endpoint)
    chained = session.headers("Accept" => "application/json")

    assert_same session.instance_variable_get(:@clients),
                chained.instance_variable_get(:@clients)
  ensure
    session&.close
  end

  def test_persistent_chaining_does_not_share_pool_for_non_persistent_sessions
    chained = session.headers("Accept" => "application/json")

    refute_same session.instance_variable_get(:@clients),
                chained.instance_variable_get(:@clients)
  end

  # base_uri

  def test_base_uri_returns_a_session_from_base_uri
    chained = session.base_uri(dummy.endpoint)

    assert_kind_of HTTP::Session, chained
  end

  def test_base_uri_preserves_base_uri_through_chaining
    chained = session.base_uri("https://example.com/api")
                     .headers("Accept" => "application/json")

    assert_equal "https://example.com/api", chained.default_options.base_uri.to_s
    assert_equal "application/json", chained.default_options.headers[:accept]
  end

  def test_base_uri_resolves_relative_request_paths_against_base_uri
    response = HTTP.base_uri(dummy.endpoint).get("/")

    assert_kind_of HTTP::Response, response
  end

  # persistent cross-origin redirects

  def test_cross_origin_follows_redirects_to_a_different_origin
    target = "#{dummy2.endpoint}/"
    response = HTTP.persistent(dummy.endpoint).follow
                   .get("#{dummy.endpoint}/cross-origin-redirect?target=#{target}")

    assert_equal 200, response.status.code
    assert_equal "<!doctype html>", response.to_s
  end

  def test_cross_origin_follows_redirects_back_to_the_original_origin
    bounce_back = "#{dummy.endpoint}/"
    target = "#{dummy2.endpoint}/cross-origin-redirect?target=#{bounce_back}"
    response = HTTP.persistent(dummy.endpoint).follow
                   .get("#{dummy.endpoint}/cross-origin-redirect?target=#{target}")

    assert_equal 200, response.status.code
    assert_equal "<!doctype html>", response.to_s
  end

  def test_cross_origin_pools_clients_per_origin
    target = "#{dummy2.endpoint}/"

    HTTP.persistent(dummy.endpoint) do |http|
      session = http.follow
      session.get("#{dummy.endpoint}/cross-origin-redirect?target=#{target}")
      clients = session.instance_variable_get(:@clients)

      assert_equal 2, clients.size
      assert_includes clients.keys, URI.parse(dummy.endpoint).origin
      assert_includes clients.keys, URI.parse(dummy2.endpoint).origin

      session.close
    end
  end

  def test_cross_origin_manages_cookies_across_cross_origin_redirect_hops
    target = "#{dummy2.endpoint}/echo-cookies"
    session = HTTP.persistent(dummy.endpoint).follow
    response = session.get("#{dummy.endpoint}/cross-origin-redirect-with-cookie?target=#{target}")

    assert_equal 200, response.status.code
    assert_equal "from_origin=yes", response.to_s
  ensure
    session&.close
  end

  def test_cross_origin_reuses_pooled_connections_within_the_same_origin
    HTTP.persistent(dummy.endpoint) do |http|
      http.get(dummy.endpoint)
      http.get(dummy.endpoint)

      clients = http.instance_variable_get(:@clients)

      assert_equal 1, clients.size
    end
  end

  def test_cross_origin_closes_all_pooled_connections_with_block_form_of_get
    closed_origins = []
    session = HTTP.persistent(dummy.endpoint).follow

    target = "#{dummy2.endpoint}/"
    session.get("#{dummy.endpoint}/cross-origin-redirect?target=#{target}") do |_res|
      session.instance_variable_get(:@clients).each_value do |client|
        original_close = client.method(:close)
        client.define_singleton_method(:close) do
          closed_origins << default_options.persistent
          original_close.call
        end
      end
    end

    assert_equal 2, closed_origins.size
  end
end
