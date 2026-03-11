# frozen_string_literal: true

require "test_helper"

describe HTTP::Connection do
  cover "HTTP::Connection*"
  let(:req) do
    HTTP::Request.new(
      verb:    :get,
      uri:     "http://example.com/",
      headers: {}
    )
  end
  let(:socket) { fake(connect: nil, close: nil) }
  let(:timeout_class) { fake(new: socket) }
  let(:opts) { HTTP::Options.new(timeout_class: timeout_class) }
  let(:connection) { HTTP::Connection.new(req, opts) }

  describe "#initialize times out" do
    let(:req) do
      HTTP::Request.new(
        verb:    :get,
        uri:     "https://example.com/",
        headers: {}
      )
    end

    it "closes the connection" do
      tls_socket = fake(
        connect:   nil,
        close:     nil,
        start_tls: ->(*) { raise HTTP::TimeoutError },
        closed?:   false
      )
      tls_timeout_class = fake(new: tls_socket)
      tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class)

      assert_raises(HTTP::TimeoutError) do
        HTTP::Connection.new(req, tls_opts)
      end
    end

    it "converts IO::TimeoutError to ConnectTimeoutError" do
      io_timeout_socket = fake(
        connect: ->(*) { raise IO::TimeoutError, "Connect timed out!" },
        close:   nil,
        closed?: false
      )
      io_timeout_class = fake(new: io_timeout_socket)
      io_opts = HTTP::Options.new(timeout_class: io_timeout_class)

      err = assert_raises(HTTP::ConnectTimeoutError) do
        HTTP::Connection.new(req, io_opts)
      end
      assert_equal "Connect timed out!", err.message
    end
  end

  describe "#read_headers!" do
    it "populates headers collection, preserving casing" do
      raw_response = "HTTP/1.1 200 OK\r\nContent-Type: text\r\nfoo_bar: 123\r\n\r\n"
      read_socket = fake(connect: nil, close: nil, readpartial: raw_response)
      read_timeout_class = fake(new: read_socket)
      read_opts = HTTP::Options.new(timeout_class: read_timeout_class)
      conn = HTTP::Connection.new(req, read_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!

      assert_equal "text", conn.headers["Content-Type"]
      assert_equal "123", conn.headers["Foo-Bar"]
      assert_equal "123", conn.headers["foo_bar"]
    end
  end

  describe "#read_headers! with 1xx informational response" do
    it "skips 100 Continue and returns the final response" do
      call_count = 0
      responses = [
        "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
        :eof
      ]
      info_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        }
      )
      info_timeout_class = fake(new: info_socket)
      info_opts = HTTP::Options.new(timeout_class: info_timeout_class)
      conn = HTTP::Connection.new(req, info_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!

      assert_equal 200, conn.status_code
      assert_equal "5", conn.headers["Content-Length"]
    end

    it "skips 100 Continue when response arrives in small chunks" do
      raw = "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"
      chunks = raw.chars + [:eof]
      call_count = 0
      chunked_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, chunks.length - 1].min
          chunks[idx].tap { call_count += 1 }
        }
      )
      chunked_timeout_class = fake(new: chunked_socket)
      chunked_opts = HTTP::Options.new(timeout_class: chunked_timeout_class)
      conn = HTTP::Connection.new(req, chunked_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!

      assert_equal 200, conn.status_code
      assert_equal "5", conn.headers["Content-Length"]
    end
  end

  describe "#send_request" do
    context "when a response is already pending" do
      it "raises StateError" do
        connection.instance_variable_set(:@pending_response, true)
        new_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        assert_raises(HTTP::StateError) { connection.send_request(new_req) }
      end
    end

    context "when a request is already pending" do
      it "raises StateError" do
        connection.instance_variable_set(:@pending_request, true)
        new_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        assert_raises(HTTP::StateError) { connection.send_request(new_req) }
      end
    end
  end

  describe "proxy connect" do
    let(:req) do
      HTTP::Request.new(
        verb:    :get,
        uri:     "https://example.com/",
        headers: {},
        proxy:   { proxy_address: "proxy.example.com", proxy_port: 8080 }
      )
    end

    context "when proxy returns non-200 status" do
      it "marks proxy connect as failed" do
        proxy_response = "HTTP/1.1 407 Proxy Authentication Required\r\nContent-Length: 0\r\n\r\n"
        call_count = 0
        proxy_socket = fake(
          connect:     nil,
          close:       nil,
          write:       lambda(&:bytesize),
          readpartial: proc {
            call_count += 1
            call_count == 1 ? proxy_response : :eof
          },
          start_tls:   ->(*) {}
        )
        proxy_timeout_class = fake(new: proxy_socket)
        proxy_opts = HTTP::Options.new(timeout_class: proxy_timeout_class)
        conn = HTTP::Connection.new(req, proxy_opts)

        assert_predicate conn, :failed_proxy_connect?
      end
    end

    context "when proxy returns 200" do
      it "completes proxy connect successfully" do
        proxy_response = "HTTP/1.1 200 Connection established\r\n\r\n"
        proxy_socket = fake(
          connect:               nil,
          close:                 nil,
          write:                 lambda(&:bytesize),
          readpartial:           proxy_response,
          start_tls:             ->(*) {},
          "hostname=":           ->(*) {},
          "sync_close=":         ->(*) {},
          post_connection_check: ->(*) {}
        )
        proxy_timeout_class = fake(new: proxy_socket)
        proxy_opts = HTTP::Options.new(timeout_class: proxy_timeout_class)
        conn = HTTP::Connection.new(req, proxy_opts)

        refute_predicate conn, :failed_proxy_connect?
      end
    end
  end

  describe "keep_alive behavior" do
    context "with HTTP/1.0 and Keep-Alive header" do
      it "keeps the connection alive" do
        response = "HTTP/1.0 200 OK\r\nConnection: Keep-Alive\r\nContent-Length: 2\r\n\r\nOK"
        ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
        ka_timeout_class = fake(new: ka_socket)
        ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
        conn = HTTP::Connection.new(req, ka_opts)
        conn.instance_variable_set(:@pending_response, true)
        conn.instance_variable_set(:@persistent, true)

        conn.read_headers!

        assert_predicate conn, :keep_alive?
      end
    end

    context "with unknown HTTP version" do
      it "does not keep the connection alive" do
        response = "HTTP/2.0 200 OK\r\nContent-Length: 2\r\n\r\nOK"
        ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
        ka_timeout_class = fake(new: ka_socket)
        ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
        conn = HTTP::Connection.new(req, ka_opts)
        conn.instance_variable_set(:@pending_response, true)
        conn.instance_variable_set(:@persistent, true)

        conn.read_headers!

        refute_predicate conn, :keep_alive?
      end
    end

    context "with HTTP/1.1 and Connection: close" do
      it "does not keep the connection alive" do
        response = "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\nOK"
        ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
        ka_timeout_class = fake(new: ka_socket)
        ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
        conn = HTTP::Connection.new(req, ka_opts)
        conn.instance_variable_set(:@pending_response, true)
        conn.instance_variable_set(:@persistent, true)

        conn.read_headers!

        refute_predicate conn, :keep_alive?
      end
    end
  end

  describe "#close" do
    context "when socket is nil" do
      it "raises NoMethodError" do
        conn = HTTP::Connection.allocate
        conn.instance_variable_set(:@socket, nil)
        conn.instance_variable_set(:@pending_response, false)
        conn.instance_variable_set(:@pending_request, false)
        assert_raises(NoMethodError) { conn.close }
      end
    end
  end

  describe "start_tls with ssl_context option" do
    it "uses provided ssl_context" do
      ssl_ctx = OpenSSL::SSL::SSLContext.new
      https_req = HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})

      start_tls_args = nil
      tls_socket = fake(
        connect:   nil,
        close:     nil,
        start_tls: ->(*args) { start_tls_args = args }
      )
      tls_timeout_class = fake(new: tls_socket)
      tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class, ssl_context: ssl_ctx)

      HTTP::Connection.new(https_req, tls_opts)

      assert_equal "example.com", start_tls_args[0]
      assert_equal ssl_ctx, start_tls_args[2]
    end
  end

  describe "read_more with nil value" do
    it "handles nil from readpartial" do
      call_count = 0
      responses = ["HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n", nil, :eof]
      rm_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc { responses[[call_count, responses.length - 1].min].tap { call_count += 1 } }
      )
      rm_timeout_class = fake(new: rm_socket)
      rm_opts = HTTP::Options.new(timeout_class: rm_timeout_class)
      conn = HTTP::Connection.new(req, rm_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      result = conn.readpartial

      assert_equal "", result
    end
  end

  describe "read_more error handling" do
    it "raises ConnectionError on IO errors during read" do
      call_count = 0
      rm_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          call_count += 1
          raise IOError, "broken" unless call_count == 1

          "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
        }
      )
      rm_timeout_class = fake(new: rm_socket)
      rm_opts = HTTP::Options.new(timeout_class: rm_timeout_class)
      conn = HTTP::Connection.new(req, rm_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      assert_raises(HTTP::ConnectionError) { conn.readpartial }
    end
  end

  describe "#readpartial" do
    it "reads data in parts" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Type: text\r\n\r\n",
        "1", "23", "456", "78", "9", "0", :eof
      ]
      rp_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     proc { call_count >= responses.length }
      )
      rp_timeout_class = fake(new: rp_socket)
      rp_opts = HTTP::Options.new(timeout_class: rp_timeout_class)
      conn = HTTP::Connection.new(req, rp_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      buffer = +""
      begin
        loop do
          s = conn.readpartial(3)
          refute_predicate conn, :finished_request? if s != ""
          buffer << s
        end
      rescue EOFError
        # Expected — end of response
      end

      assert_equal "1234567890", buffer
      assert_predicate conn, :finished_request?
    end

    it "raises EOFError when no response is pending" do
      assert_raises(EOFError) { connection.readpartial }
    end

    it "fills outbuf when provided" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
        :eof
      ]
      ob_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     proc { call_count >= responses.length }
      )
      ob_timeout_class = fake(new: ob_socket)
      ob_opts = HTTP::Options.new(timeout_class: ob_timeout_class)
      conn = HTTP::Connection.new(req, ob_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      outbuf = +""
      result = conn.readpartial(16_384, outbuf)

      assert_equal "hello", outbuf
      assert_same outbuf, result
    end
  end
end
