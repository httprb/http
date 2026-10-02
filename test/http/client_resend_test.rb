# frozen_string_literal: true

require "test_helper"

require "stringio"

require "support/scripted_server"

class HTTPClientResendTest < Minitest::Test
  cover "HTTP::Client*"

  CountingFeature = Class.new(HTTP::Feature) do
    attr_reader :requests, :responses, :errors

    def initialize
      super
      @requests  = []
      @responses = 0
      @errors    = 0
    end

    def on_request(request)
      @requests << request.uri.path
    end

    def wrap_response(response)
      @responses += 1
      response
    end

    def on_error(_request, _error)
      @errors += 1
    end
  end

  # Unwinds like Thread#exit: ensure clauses run, rescue clauses do not
  InterruptingFeature = Class.new(HTTP::Feature) do
    def wrap_response(response)
      throw :interrupted if response.request.uri.path == "/interrupt"

      response
    end
  end

  def teardown
    @client&.close
    @server&.shutdown
    @proxy&.shutdown
    super
  end

  def test_resends_get_after_idle_connection_is_closed
    start(idle_close(:fin), serve)
    build_client
    get
    @server.wait_closed

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_resends_get_after_idle_connection_is_reset
    start(idle_close(:reset), serve)
    build_client
    get
    @server.wait_closed

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_resends_get_after_idle_close_with_unread_body
    start(idle_close(:fin), serve)
    build_client
    @client.get("#{@server.endpoint}/")
    @server.wait_closed

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_resends_get_after_unread_body_too_big_to_flush
    size = HTTP::Connection::MAX_FLUSH_SIZE + 1
    start(answer("HTTP/1.1 200 OK\r\nContent-Length: #{size}\r\n\r\n#{'x' * size}"), serve)
    build_client
    @client.get("#{@server.endpoint}/")

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_resends_identical_get_when_connection_closes_after_reading_it
    start(close_after_second_request, serve)
    build_client
    get("/first")

    assert_equal "ok", get("/second")

    _, sent, resent = @server.requests

    assert_match %r{\AGET /second }, sent
    assert_equal sent, resent
    assert_equal 2, @server.accepts
  end

  def test_resends_post_with_idempotency_key
    start(close_after_second_request, serve)
    build_client
    get
    response = @client.post("#{@server.endpoint}/", headers: { "Idempotency-Key" => "abc" }, body: "data")
    _, sent, resent = @server.requests

    assert_equal "ok", response.to_s
    assert_match(/^Idempotency-Key: abc\r$/i, sent)
    assert sent.end_with?("\r\n\r\ndata")
    assert_equal sent, resent
    assert_equal 3, @server.requests.size
    assert_equal 2, @server.accepts
  end

  def test_does_not_resend_post
    start(close_after_second_request, serve)
    build_client
    get

    assert_raises(HTTP::ConnectionError) { @client.post("#{@server.endpoint}/", body: "data") }
    assert_equal 2, @server.requests.size
    assert_equal 1, @server.accepts
  end

  def test_does_not_resend_request_with_io_body
    start(close_after_second_request, serve)
    build_client
    get

    assert_raises(HTTP::ConnectionError) { @client.put("#{@server.endpoint}/", body: StringIO.new("data")) }
    assert_equal 2, @server.requests.size
    assert_equal 1, @server.accepts
  end

  def test_does_not_resend_after_partial_response
    start(reply_to_second_request("HTTP/1.1 200 OK\r\nContent-"), serve)
    build_client
    get

    assert_raises(HTTP::ConnectionError) { get }
    assert_equal 1, @server.accepts
  end

  def test_does_not_resend_after_malformed_response
    start(reply_to_second_request("garbage\r\n\r\n"), serve)
    build_client
    get

    assert_raises(HTTP::ConnectionError) { get }
    assert_equal 1, @server.accepts
  end

  def test_does_not_resend_after_informational_response
    start(reply_to_second_request("HTTP/1.1 100 Continue\r\n\r\n"), serve)
    build_client
    get

    assert_raises(HTTP::ConnectionError) { get }
    assert_equal 1, @server.accepts
  end

  def test_does_not_resend_after_read_timeout
    start(on_second_request(&:read_request), serve)
    build_client(timeout_class: HTTP::Timeout::PerOperation, timeout_options: { read_timeout: 0.2 })
    get

    assert_raises(HTTP::TimeoutError) { get }
    assert_equal 1, @server.accepts
  end

  def test_does_not_resend_on_fresh_connection
    start(read_then_close, serve)
    build_client

    assert_raises(HTTP::ConnectionError) { get }
    assert_equal 1, @server.accepts
  end

  def test_resends_at_most_once
    start(close_after_second_request, read_then_close)
    build_client
    get

    assert_raises(HTTP::ConnectionError) { get }
    assert_equal 3, @server.requests.size
    assert_equal 2, @server.accepts
  end

  def test_closes_dead_connection_before_resending
    start(close_after_second_request, serve)
    build_client
    get
    dead = @client.instance_variable_get(:@connection).instance_variable_get(:@socket)

    assert_equal "ok", get
    assert_predicate dead, :closed?
  end

  def test_does_not_reuse_connection_after_resend_is_interrupted
    start(close_after_second_request, serve)
    build_client(features: { interrupting: InterruptingFeature.new })
    get
    catch(:interrupted) { get("/interrupt") }

    assert_equal "ok", get
    assert_equal 3, @server.accepts
  end

  def test_raises_when_reconnecting_fails
    start(close_after_second_request, serve)
    build_client
    get

    HTTP::Connection.stub(:new, ->(*) { raise HTTP::ConnectionError, "refused" }) do
      err = assert_raises(HTTP::ConnectionError) { get }

      assert_equal "refused", err.message
    end

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_does_not_resend_when_retriable
    start(close_after_second_request, serve)
    build_client(retriable: { tries: 1 })
    get

    assert_raises(HTTP::OutOfRetriesError) { get }
    assert_equal 1, @server.accepts
  end

  def test_retriable_retries_on_a_new_connection
    start(close_after_second_request, serve)
    build_client(retriable: { tries: 2, delay: 0 })
    get

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_features_see_each_call_once_when_resend_succeeds
    feature = CountingFeature.new
    start(close_after_second_request, serve)
    build_client(features: { counting: feature })
    get
    get

    assert_equal 2, @server.accepts
    assert_equal %w[/ /], feature.requests
    assert_equal 2, feature.responses
    assert_equal 0, feature.errors
  end

  def test_features_see_one_error_when_resend_fails
    feature = CountingFeature.new
    start(close_after_second_request, read_then_close)
    build_client(features: { counting: feature })
    get

    assert_raises(HTTP::ConnectionError) { get }
    assert_equal %w[/ /], feature.requests
    assert_equal 1, feature.errors
  end

  def test_resends_get_after_tls_connection_closes_without_close_notify
    start(idle_close(:fin), serve, ssl: true)
    build_ssl_client
    get
    @server.wait_closed

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_resends_get_when_tls_connection_closes_after_reading_it
    start(close_after_second_request, serve, ssl: true)
    build_ssl_client
    get

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_resends_at_most_once_over_tls
    start(close_after_second_request, read_then_close, ssl: true)
    build_ssl_client
    get

    # OpenSSL 3 reports an EOF without close_notify as SSLError, JRuby as a plain EOF
    assert_raises(OpenSSL::SSL::SSLError, HTTP::ResponseHeaderError) { get }
    assert_equal 3, @server.requests.size
    assert_equal 2, @server.accepts
  end

  def test_resends_get_after_tls_close_notify
    start(idle_close(:close_notify), serve, ssl: true)
    build_ssl_client
    get
    @server.wait_closed

    assert_equal "ok", get
    assert_equal 2, @server.accepts
  end

  def test_resends_get_through_proxy_after_tunnel_is_closed
    start(serve, ssl: true)
    @proxy = TunnelClosingProxy.new
    Thread.new { @proxy.start }
    @proxy.wait_ready
    build_ssl_client(proxy: { proxy_address: @proxy.addr, proxy_port: @proxy.port })
    get
    @proxy.close_tunnels

    assert_equal "ok", get
    assert_equal 2, @proxy.connects
    assert_equal 2, @server.accepts
  end

  private

  def start(*handlers, ssl: false)
    @server = ScriptedServer.new(*handlers, ssl: ssl)
  end

  def build_client(**)
    @client = HTTP::Client.new(persistent: @server.endpoint, **)
  end

  def build_ssl_client(**)
    build_client(ssl_context: SSLHelper.client_context, **)
  end

  def get(path = "/")
    @client.get("#{@server.endpoint}#{path}").to_s
  end

  def serve
    :serve.to_proc
  end

  def answer(data)
    lambda do |peer|
      peer.read_request
      peer.write(data)
    end
  end

  def read_then_close
    lambda do |peer|
      peer.read_request
      peer.fin
    end
  end

  # Answers the first request, then closes the idle connection
  def idle_close(action)
    lambda do |peer|
      peer.read_request
      peer.respond
      peer.public_send(action)
    end
  end

  # Answers the first request and hands the peer over once the second arrives
  def on_second_request
    lambda do |peer|
      peer.read_request
      peer.respond
      peer.read_request
      yield peer
    end
  end

  def close_after_second_request
    on_second_request(&:fin)
  end

  def reply_to_second_request(data)
    on_second_request do |peer|
      peer.write(data)
      peer.fin
    end
  end
end
