# frozen_string_literal: true

require "test_helper"

require "uri"
require "logger"

require "support/http_handling_shared"
require "support/dummy_server"
require "support/ssl_helper"

StubbedClient = Class.new(HTTP::Client) do
  def perform(request, options)
    stubbed = stubs[HTTP::URI::NORMALIZER.call(request.uri).to_s]
    stubbed ? stubbed.call(request) : super
  end

  def stubs
    @stubs ||= {}
  end

  def stub(stubs)
    @stubs = stubs.transform_keys do |k|
      HTTP::URI::NORMALIZER.call(k).to_s
    end

    self
  end
end

class HTTPClientTest < Minitest::Test
  cover "HTTP::Client*"
  run_server(:dummy) { DummyServer.new }

  def capture_request(client, &)
    captured_req = nil
    client.stub(:perform, lambda { |req, _opts|
      captured_req = req
      nil
    }, &)
    captured_req
  end

  def redirect_response(location, status = 302)
    lambda do |request|
      HTTP::Response.new(
        status:  status,
        version: "1.1",
        headers: { "Location" => location },
        body:    "",
        request: request
      )
    end
  end

  def simple_response(body, status = 200)
    lambda do |request|
      HTTP::Response.new(
        status:  status,
        version: "1.1",
        body:    body,
        request: request
      )
    end
  end

  def client
    @client ||= HTTP::Client.new
  end

  def parse_query(str)
    URI.decode_www_form(str).group_by(&:first).transform_values { |v| v.map(&:last) }
  end

  # following redirects

  def test_following_redirects_returns_response_of_new_location
    client = StubbedClient.new(follow: true).stub(
      "http://example.com/"     => redirect_response("http://example.com/blog"),
      "http://example.com/blog" => simple_response("OK")
    )

    assert_equal "OK", client.get("http://example.com/").to_s
  end

  def test_following_redirects_prepends_previous_request_uri_scheme_and_host_if_needed
    client = StubbedClient.new(follow: true).stub(
      "http://example.com/"           => redirect_response("/index"),
      "http://example.com/index"      => redirect_response("/index.html"),
      "http://example.com/index.html" => simple_response("OK")
    )

    assert_equal "OK", client.get("http://example.com/").to_s
  end

  def test_following_redirects_fails_upon_endless_redirects
    client = StubbedClient.new(follow: true).stub(
      "http://example.com/" => redirect_response("/")
    )

    assert_raises(HTTP::Redirector::EndlessRedirectError) { client.get("http://example.com/") }
  end

  def test_following_redirects_fails_if_max_amount_of_hops_reached
    client = StubbedClient.new(follow: { max_hops: 5 }).stub(
      "http://example.com/"  => redirect_response("/1"),
      "http://example.com/1" => redirect_response("/2"),
      "http://example.com/2" => redirect_response("/3"),
      "http://example.com/3" => redirect_response("/4"),
      "http://example.com/4" => redirect_response("/5"),
      "http://example.com/5" => redirect_response("/6"),
      "http://example.com/6" => simple_response("OK")
    )

    assert_raises(HTTP::Redirector::TooManyRedirectsError) { client.get("http://example.com/") }
  end

  def test_following_redirects_with_non_ascii_urls_theoretically_works_like_a_charm
    client = StubbedClient.new(follow: true).stub(
      "http://example.com/"      => redirect_response("/könig"),
      "http://example.com/könig" => simple_response("OK")
    )

    client.get "http://example.com/könig"
  end

  def test_following_redirects_with_non_ascii_urls_follows_redirects
    client = StubbedClient.new(follow: true).stub(
      "http://example.com/"      => redirect_response("/könig"),
      "http://example.com/könig" => simple_response("OK")
    )

    assert_equal "OK", client.get("http://example.com/").to_s
  end

  # following redirects with logging

  def test_following_redirects_with_logging_logs_all_requests
    logdev = StringIO.new
    logger = Logger.new(logdev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
    logger.level = Logger::INFO

    client = StubbedClient.new(follow: true, features: { logging: { logger: logger } }).stub(
      "http://example.com/"  => redirect_response("/1"),
      "http://example.com/1" => redirect_response("/2"),
      "http://example.com/2" => redirect_response("/3"),
      "http://example.com/3" => simple_response("OK")
    )

    client.get("http://example.com/")

    assert_equal <<~OUTPUT, logdev.string
      ** INFO **
      > GET http://example.com/
      ** INFO **
      > GET http://example.com/1
      ** INFO **
      > GET http://example.com/2
      ** INFO **
      > GET http://example.com/3
    OUTPUT
  end

  # base_uri

  def test_base_uri_resolves_relative_paths_against_base_uri
    client = StubbedClient.new(base_uri: "https://example.com/api").stub(
      "https://example.com/api/users" => simple_response("OK")
    )

    assert_equal "OK", client.get("users").to_s
  end

  def test_base_uri_resolves_absolute_paths_from_host_root
    client = StubbedClient.new(base_uri: "https://example.com/api").stub(
      "https://example.com/users" => simple_response("OK")
    )

    assert_equal "OK", client.get("/users").to_s
  end

  def test_base_uri_ignores_base_uri_for_absolute_urls
    client = StubbedClient.new(base_uri: "https://example.com/api").stub(
      "https://other.com/path" => simple_response("OK")
    )

    assert_equal "OK", client.get("https://other.com/path").to_s
  end

  def test_base_uri_handles_parent_path_traversal
    client = StubbedClient.new(base_uri: "https://example.com/api/v1").stub(
      "https://example.com/api/v2" => simple_response("OK")
    )

    assert_equal "OK", client.get("../v2").to_s
  end

  def test_base_uri_handles_base_uri_without_trailing_slash
    client = StubbedClient.new(base_uri: "https://example.com/api").stub(
      "https://example.com/api/users" => simple_response("OK")
    )

    assert_equal "OK", client.get("users").to_s
  end

  def test_base_uri_handles_base_uri_with_trailing_slash
    client = StubbedClient.new(base_uri: "https://example.com/api/").stub(
      "https://example.com/api/users" => simple_response("OK")
    )

    assert_equal "OK", client.get("users").to_s
  end

  # parsing params

  def test_parsing_params_accepts_params_within_the_provided_url
    req = capture_request(client) { client.get("http://example.com/?foo=bar") }

    assert_equal({ "foo" => %w[bar] }, parse_query(req.uri.query))
  end

  def test_parsing_params_combines_get_params_from_the_uri_with_the_passed_in_params
    req = capture_request(client) { client.get("http://example.com/?foo=bar", params: { baz: "quux" }) }

    assert_equal({ "foo" => %w[bar], "baz" => %w[quux] }, parse_query(req.uri.query))
  end

  def test_parsing_params_merges_duplicate_values
    req = capture_request(client) { client.get("http://example.com/?a=1", params: { a: 2 }) }

    assert_match(/^(a=1&a=2|a=2&a=1)$/, req.uri.query)
  end

  def test_parsing_params_does_not_modify_query_part_if_no_params_were_given
    req = capture_request(client) { client.get("http://example.com/?deadbeef") }

    assert_equal "deadbeef", req.uri.query
  end

  def test_parsing_params_does_not_corrupt_index_less_arrays
    req = capture_request(client) { client.get("http://example.com/?a[]=b&a[]=c", params: { d: "e" }) }

    assert_equal({ "a[]" => %w[b c], "d" => %w[e] }, parse_query(req.uri.query))
  end

  def test_parsing_params_properly_encodes_colons
    req = capture_request(client) { client.get("http://example.com/", params: { t: "1970-01-01T00:00:00Z" }) }

    assert_equal "t=1970-01-01T00%3A00%3A00Z", req.uri.query
  end

  def test_parsing_params_does_not_convert_newlines_into_crlf_before_encoding_string_values
    req = capture_request(client) { client.get("http://example.com/", params: { foo: "bar\nbaz" }) }

    assert_equal "foo=bar%0Abaz", req.uri.query
  end

  # passing multipart form data

  def test_passing_multipart_form_data_creates_url_encoded_form_data_object
    req = capture_request(client) { client.get("http://example.com/", form: { foo: "bar" }) }

    assert_kind_of HTTP::FormData::Urlencoded, req.body.source
    assert_equal "foo=bar", req.body.source.to_s
  end

  def test_passing_multipart_form_data_creates_multipart_form_data_object
    req = capture_request(client) { client.get("http://example.com/", form: { foo: HTTP::FormData::Part.new("content") }) }

    assert_kind_of HTTP::FormData::Multipart, req.body.source
    assert_includes req.body.source.to_s, "content"
  end

  def test_passing_multipart_form_data_with_multipart_object_passes_it_through_unchanged
    form_data = HTTP::FormData::Multipart.new({ foo: "bar" })
    req = capture_request(client) { client.get("http://example.com/", form: form_data) }

    assert_same form_data, req.body.source
    assert_match(/^Content-Disposition: form-data; name="foo"\r\n\r\nbar\r\n/m, req.body.source.to_s)
  end

  def test_passing_multipart_form_data_with_urlencoded_object_passes_it_through_unchanged
    form_data = HTTP::FormData::Urlencoded.new({ foo: "bar" })
    req = capture_request(client) { client.get("http://example.com/", form: form_data) }

    assert_same form_data, req.body.source
  end

  # passing json

  def test_passing_json_encodes_given_object
    req = capture_request(client) { client.get("http://example.com/", json: { foo: :bar }) }

    assert_equal '{"foo":"bar"}', req.body.source
    assert_equal "application/json; charset=utf-8", req.headers["Content-Type"]
  end

  # #request with non-ASCII URLs

  def test_request_with_non_ascii_urls_theoretically_works_like_a_charm
    client.get "#{dummy.endpoint}/könig"
  end

  def test_request_with_non_ascii_urls_handles_multi_byte_characters
    client.get "#{dummy.endpoint}/héllö-wörld"
  end

  # #request with explicitly given Host header

  def test_request_with_explicitly_given_host_header_keeps_host_header_as_is
    headers = { "Host" => "another.example.com" }
    host_client = HTTP::Client.new(headers: headers)
    req = capture_request(host_client) { host_client.request(:get, "http://example.com/") }

    assert_equal "another.example.com", req.headers["Host"]
  end

  # #request when :auto_deflate was specified

  def test_request_when_auto_deflate_deletes_content_length_header
    headers = { "Content-Length" => "12" }
    deflate_client = HTTP::Client.new(headers: headers, features: { auto_deflate: {} }, body: "foo")
    req = capture_request(deflate_client) { deflate_client.request(:get, "http://example.com/") }

    assert_nil req.headers["Content-Length"]
  end

  def test_request_when_auto_deflate_sets_content_encoding_header
    headers = { "Content-Length" => "12" }
    deflate_client = HTTP::Client.new(headers: headers, features: { auto_deflate: {} }, body: "foo")
    req = capture_request(deflate_client) { deflate_client.request(:get, "http://example.com/") }

    assert_equal "gzip", req.headers["Content-Encoding"]
  end

  def test_request_when_auto_deflate_and_no_body_does_not_set_content_encoding_header
    headers = { "Content-Length" => "12" }
    deflate_client = HTTP::Client.new(headers: headers, features: { auto_deflate: {} })
    req = capture_request(deflate_client) { deflate_client.request(:get, "http://example.com/") }

    refute_includes req.headers, "Content-Encoding"
  end

  # #request Feature

  def feature_class
    @feature_class ||= Class.new(HTTP::Feature) do
      attr_reader :captured_request, :captured_response, :captured_error

      def wrap_request(request)
        @captured_request = request
      end

      def wrap_response(response)
        @captured_response = response
      end

      def on_error(request, error)
        @captured_request = request
        @captured_error = error
      end
    end
  end

  def test_feature_is_given_a_chance_to_wrap_the_request
    feature_instance = feature_class.new

    response = client.use(test_feature: feature_instance)
                     .request(:get, dummy.endpoint)

    assert_equal 200, response.code
    assert_equal :get, feature_instance.captured_request.verb
    assert_equal "#{dummy.endpoint}/", feature_instance.captured_request.uri.to_s
  end

  def test_feature_is_given_a_chance_to_wrap_the_response
    feature_instance = feature_class.new

    response = client.use(test_feature: feature_instance)
                     .request(:get, dummy.endpoint)

    assert_equal response, feature_instance.captured_response
  end

  def test_feature_is_given_a_chance_to_handle_an_error
    sleep_url = "#{dummy.endpoint}/sleep"
    feature_instance = feature_class.new

    assert_raises(HTTP::TimeoutError) do
      client.use(test_feature: feature_instance)
            .timeout(0.01)
            .request(:post, sleep_url)
    end

    assert_kind_of HTTP::TimeoutError, feature_instance.captured_error
    assert_equal :post, feature_instance.captured_request.verb
    assert_equal sleep_url, feature_instance.captured_request.uri.to_s
  end

  def test_feature_is_given_a_chance_to_handle_a_connection_timeout_error
    sleep_url = "#{dummy.endpoint}/sleep"
    feature_instance = feature_class.new

    TCPSocket.stub(:open, ->(*) { sleep 0.1 }) do
      assert_raises(HTTP::ConnectTimeoutError) do
        client.use(test_feature: feature_instance)
              .timeout(0.001)
              .request(:post, sleep_url)
      end
    end
    assert_kind_of HTTP::ConnectTimeoutError, feature_instance.captured_error
  end

  def test_feature_handles_responses_in_the_reverse_order_from_the_requests
    feature_class_order =
      Class.new(HTTP::Feature) do
        @order = []

        class << self
          attr_reader :order
        end

        def initialize(id:)
          super()
          @id = id
        end

        def wrap_request(req)
          self.class.order << "request.#{@id}"
          req
        end

        def wrap_response(res)
          self.class.order << "response.#{@id}"
          res
        end
      end
    feature_instance_a = feature_class_order.new(id: "a")
    feature_instance_b = feature_class_order.new(id: "b")
    feature_instance_c = feature_class_order.new(id: "c")

    client.use(
      test_feature_a: feature_instance_a,
      test_feature_b: feature_instance_b,
      test_feature_c: feature_instance_c
    ).request(:get, dummy.endpoint)

    assert_equal(
      ["request.a", "request.b", "request.c", "response.c", "response.b", "response.a"],
      feature_class_order.order
    )
  end

  def test_feature_calls_on_request_once_per_attempt
    feature_class_on_request =
      Class.new(HTTP::Feature) do
        attr_reader :call_count

        def initialize
          super
          @call_count = 0
        end

        def on_request(_request)
          @call_count += 1
        end
      end
    feature_instance = feature_class_on_request.new

    client.use(test_feature: feature_instance)
          .request(:get, dummy.endpoint)

    assert_equal 1, feature_instance.call_count
  end

  def test_feature_calls_on_request_once_per_retry_attempt
    feature_class_on_request =
      Class.new(HTTP::Feature) do
        attr_reader :call_count

        def initialize
          super
          @call_count = 0
        end

        def on_request(_request)
          @call_count += 1
        end
      end
    feature_instance = feature_class_on_request.new

    client.use(test_feature: feature_instance)
          .retriable(delay: 0, retry_statuses: [500])
          .request(:get, "#{dummy.endpoint}/retry-2")

    assert_equal 2, feature_instance.call_count
  end

  def test_feature_wraps_each_retry_attempt_with_around_request
    feature_class_around =
      Class.new(HTTP::Feature) do
        attr_reader :events

        def initialize
          super
          @events = []
        end

        def around_request(request)
          @events << :before
          yield(request).tap do
            @events << :after
          end
        end
      end
    feature_instance = feature_class_around.new

    client.use(test_feature: feature_instance)
          .retriable(delay: 0, retry_statuses: [500])
          .request(:get, "#{dummy.endpoint}/retry-2")

    assert_equal %i[before after before after], feature_instance.events
  end

  def test_feature_wraps_the_exchange_with_around_request_in_feature_order
    feature_class_around =
      Class.new(HTTP::Feature) do
        @order = []

        class << self
          attr_reader :order
        end

        def initialize(id:)
          super()
          @id = id
        end

        def around_request(request)
          self.class.order << "before.#{@id}"
          yield(request).tap do
            self.class.order << "after.#{@id}"
          end
        end
      end
    feature_instance_a = feature_class_around.new(id: "a")
    feature_instance_b = feature_class_around.new(id: "b")
    feature_instance_c = feature_class_around.new(id: "c")

    client.use(
      test_feature_a: feature_instance_a,
      test_feature_b: feature_instance_b,
      test_feature_c: feature_instance_c
    ).request(:get, dummy.endpoint)

    assert_equal(
      ["before.a", "before.b", "before.c", "after.c", "after.b", "after.a"],
      feature_class_around.order
    )
  end

  # #perform

  def test_perform_calls_finish_response_once_body_was_fully_flushed
    body = client.get(dummy.endpoint).to_s

    assert_equal "<!doctype html>", body
  end

  def test_perform_provides_access_to_the_request_from_the_response
    unique_value = "20190424"
    response = client.headers("X-Value" => unique_value).get(dummy.endpoint)

    assert_kind_of HTTP::Request, response.request
    assert_equal unique_value, response.request.headers["X-Value"]
  end

  def test_perform_with_head_request_does_not_iterate_through_body
    response = client.head(dummy.endpoint)

    assert_equal 200, response.status.to_i
  end

  def test_perform_with_head_request_finishes_response_after_headers_were_received
    response = client.head(dummy.endpoint)

    assert_equal 200, response.status.to_i
  end

  def test_perform_when_server_fully_flushes_response_in_one_chunk_properly_reads_body
    response_data = [
      "HTTP/1.1 200 OK\r\n" \
      "Content-Type: text/html\r\n" \
      "Server: WEBrick/1.3.1 (Ruby/1.9.3/2013-11-22)\r\n" \
      "Date: Mon, 24 Mar 2014 00:32:22 GMT\r\n" \
      "Content-Length: 15\r\n" \
      "Connection: Keep-Alive\r\n" \
      "\r\n" \
      "<!doctype html>"
    ]

    socket_spy = fake(
      close:       nil,
      closed?:     true,
      readpartial: proc { response_data.shift || :eof },
      write:       proc(&:bytesize)
    )

    TCPSocket.stub(:open, socket_spy) do
      body = client.get(dummy.endpoint).to_s

      assert_equal "<!doctype html>", body
    end
  end

  def test_perform_when_uses_chunked_transfer_encoding_properly_reads_body
    response_data = [
      "HTTP/1.1 200 OK\r\n" \
      "Content-Type: application/json\r\n" \
      "Transfer-Encoding: chunked\r\n" \
      "Connection: close\r\n" \
      "\r\n" \
      "9\r\n" \
      "{\"state\":\r\n" \
      "5\r\n" \
      "\"ok\"}\r\n" \
      "0\r\n" \
      "\r\n"
    ]

    socket_spy = fake(
      close:       nil,
      closed?:     true,
      readpartial: proc { response_data.shift || :eof },
      write:       proc(&:bytesize)
    )

    TCPSocket.stub(:open, socket_spy) do
      body = client.get(dummy.endpoint).to_s

      assert_equal '{"state":"ok"}', body
    end
  end

  def test_perform_when_uses_chunked_transfer_encoding_with_broken_body_raises_connection_error
    response_data = [
      "HTTP/1.1 200 OK\r\n" \
      "Content-Type: application/json\r\n" \
      "Transfer-Encoding: chunked\r\n" \
      "Connection: close\r\n" \
      "\r\n" \
      "9\r\n" \
      "{\"state\":\r\n"
    ]

    socket_spy = fake(
      close:       nil,
      closed?:     true,
      readpartial: proc { response_data.shift || :eof },
      write:       proc(&:bytesize)
    )

    TCPSocket.stub(:open, socket_spy) do
      assert_raises(HTTP::ConnectionError) { client.get(dummy.endpoint).to_s }
    end
  end

  # #perform with failed proxy connect

  def test_perform_with_failed_proxy_connect_skips_sending_request
    proxy_client = HTTP::Client.new
    conn = fake(
      failed_proxy_connect?:  true,
      proxy_response_headers: {},
      status_code:            407,
      http_version:           "1.1",
      headers:                HTTP::Headers.new,
      finish_response:        nil,
      keep_alive?:            true,
      expired?:               false,
      close:                  nil,
      "pending_response=":    ->(*) {}
    )
    proxy_client.instance_variable_set(:@connection, conn)
    proxy_client.instance_variable_set(:@state, :clean)
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
    response = proxy_client.perform(req, HTTP::Options.new)

    assert_equal 407, response.status.to_i
  end
end

class HTTPClientHTTPHandlingTest < Minitest::Test
  run_server(:dummy) { DummyServer.new }

  def server
    dummy
  end

  def build_client(**)
    HTTP::Client.new(**)
  end

  include HTTPHandlingTests
end

class HTTPClientSSLTest < Minitest::Test
  run_server(:dummy_ssl) { DummyServer.new(ssl: true) }

  def server
    dummy_ssl
  end

  def build_client(**)
    HTTP::Client.new(**, ssl_context: SSLHelper.client_context)
  end

  include HTTPHandlingTests

  def test_ssl_just_works
    response = build_client.get(dummy_ssl.endpoint)

    assert_equal "<!doctype html>", response.body.to_s
  end

  def test_ssl_fails_with_ssl_error_if_host_mismatch
    assert_raises(OpenSSL::SSL::SSLError) do
      build_client.get(dummy_ssl.endpoint.gsub("127.0.0.1", "localhost"))
    end
  end

  def test_ssl_with_ssl_options_instead_of_a_context_just_works
    ssl_client = HTTP::Client.new(ssl: SSLHelper.client_params)
    response = ssl_client.get(dummy_ssl.endpoint)

    assert_equal "<!doctype html>", response.body.to_s
  end
end
