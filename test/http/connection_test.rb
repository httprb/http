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

  # ---------------------------------------------------------------------------
  # #initialize
  # ---------------------------------------------------------------------------
  describe "#initialize" do
    it "initializes state from options" do
      refute_predicate connection, :failed_proxy_connect?
      assert_predicate connection, :finished_request?
      assert_predicate connection, :expired?
    end

    it "raises ConnectionError on IOError during connect" do
      err_socket = fake(
        connect: ->(*) { raise IOError, "connection refused" }
      )
      err_timeout_class = fake(new: err_socket)
      err_opts = HTTP::Options.new(timeout_class: err_timeout_class)

      err = assert_raises(HTTP::ConnectionError) do
        HTTP::Connection.new(req, err_opts)
      end
      assert_includes err.message, "failed to connect"
      assert_includes err.message, "connection refused"
      refute_nil err.backtrace
    end

    it "raises ConnectionError on SocketError during connect" do
      err_socket = fake(
        connect: ->(*) { raise SocketError, "dns failure" }
      )
      err_timeout_class = fake(new: err_socket)
      err_opts = HTTP::Options.new(timeout_class: err_timeout_class)

      err = assert_raises(HTTP::ConnectionError) do
        HTTP::Connection.new(req, err_opts)
      end
      assert_includes err.message, "failed to connect"
      assert_includes err.message, "dns failure"
    end

    it "raises ConnectionError on SystemCallError during connect" do
      err_socket = fake(
        connect: ->(*) { raise Errno::ECONNREFUSED, "refused" }
      )
      err_timeout_class = fake(new: err_socket)
      err_opts = HTTP::Options.new(timeout_class: err_timeout_class)

      err = assert_raises(HTTP::ConnectionError) do
        HTTP::Connection.new(req, err_opts)
      end
      assert_includes err.message, "failed to connect"
    end

    context "when TimeoutError occurs" do
      let(:https_req) do
        HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})
      end

      it "closes the socket and re-raises" do
        closed = false
        tls_socket = fake(
          connect:   nil,
          close:     -> { closed = true },
          start_tls: ->(*) { raise HTTP::TimeoutError },
          closed?:   false
        )
        tls_timeout_class = fake(new: tls_socket)
        tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class)

        assert_raises(HTTP::TimeoutError) do
          HTTP::Connection.new(https_req, tls_opts)
        end
        assert closed, "socket should have been closed"
      end
    end

    context "when IO::TimeoutError occurs" do
      it "converts to ConnectTimeoutError with original message and backtrace" do
        io_timeout_socket = fake(
          connect: lambda { |*|
            raise IO::TimeoutError, "Connect timed out!"
          },
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
  end

  # ---------------------------------------------------------------------------
  # #send_request
  # ---------------------------------------------------------------------------
  describe "#send_request" do
    it "streams the request to the socket and sets pending state" do
      sr_req = HTTP::Request.new(verb: :get, uri: "http://example.com/path", headers: {})

      write_socket = fake(connect: nil, close: nil, write: proc(&:bytesize))
      write_timeout_class = fake(new: write_socket)
      write_opts = HTTP::Options.new(timeout_class: write_timeout_class)
      conn = HTTP::Connection.new(req, write_opts)

      assert_predicate conn, :finished_request?

      conn.send_request(sr_req)

      refute_predicate conn, :finished_request?
      assert conn.instance_variable_get(:@pending_response)
      refute conn.instance_variable_get(:@pending_request)
    end

    context "when a request is already pending" do
      it "raises StateError with specific message" do
        connection.instance_variable_set(:@pending_request, true)
        sr_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        err = assert_raises(HTTP::StateError) { connection.send_request(sr_req) }
        assert_includes err.message, "response is pending"
      end
    end

    it "sets pending_request true before streaming then false after" do
      pending_during_stream = nil
      conn = nil
      stream_socket = fake(
        connect: nil,
        close:   nil,
        write:   proc { |data|
          pending_during_stream = conn.instance_variable_get(:@pending_request)
          data.bytesize
        }
      )
      stream_timeout_class = fake(new: stream_socket)
      stream_opts = HTTP::Options.new(timeout_class: stream_timeout_class)
      conn = HTTP::Connection.new(req, stream_opts)

      sr_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
      conn.send_request(sr_req)

      assert pending_during_stream, "pending_request should be true during streaming"
      assert conn.instance_variable_get(:@pending_response)
      refute conn.instance_variable_get(:@pending_request)
    end

    it "calls req.stream with the socket" do
      stream_args = nil
      sr_req = Minitest::Mock.new
      sr_req.expect(:stream, nil) do |s|
        stream_args = s
        true
      end

      write_socket = fake(connect: nil, close: nil, write: lambda(&:bytesize))
      write_timeout_class = fake(new: write_socket)
      write_opts = HTTP::Options.new(timeout_class: write_timeout_class)
      conn = HTTP::Connection.new(req, write_opts)

      conn.send_request(sr_req)

      assert_same conn.instance_variable_get(:@socket), stream_args
      sr_req.verify
    end
  end

  # ---------------------------------------------------------------------------
  # #readpartial
  # ---------------------------------------------------------------------------
  describe "#readpartial" do
    it "raises EOFError when no response is pending" do
      assert_raises(EOFError) { connection.readpartial }
    end

    it "reads data from socket and returns chunks" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
        :eof
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
      chunk = conn.readpartial

      assert_equal "hello", chunk
    end

    it "reads data in parts and finishes" do
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
        # Expected
      end

      assert_equal "1234567890", buffer
      assert_predicate conn, :finished_request?
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

    it "uses the size parameter when reading from socket" do
      call_count = 0
      read_sizes = []
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n",
        "helloworld",
        :eof
      ]
      sz_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc { |size, *|
          read_sizes << size
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     proc { call_count >= responses.length }
      )
      sz_timeout_class = fake(new: sz_socket)
      sz_opts = HTTP::Options.new(timeout_class: sz_timeout_class)
      conn = HTTP::Connection.new(req, sz_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      conn.readpartial(42)

      assert_includes read_sizes, 42
    end

    it "detects premature EOF on framed Content-Length response" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nhello",
        :eof
      ]
      eof_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      eof_timeout_class = fake(new: eof_socket)
      eof_opts = HTTP::Options.new(timeout_class: eof_timeout_class)
      conn = HTTP::Connection.new(req, eof_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      chunk = conn.readpartial

      assert_equal "hello", chunk
      err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
      assert_includes err.message, "response body ended prematurely"
    end

    it "detects premature EOF on Transfer-Encoding chunked response" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n",
        :eof
      ]
      eof_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      eof_timeout_class = fake(new: eof_socket)
      eof_opts = HTTP::Options.new(timeout_class: eof_timeout_class)
      conn = HTTP::Connection.new(req, eof_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      chunk = conn.readpartial

      assert_equal "hello", chunk
      err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
      assert_includes err.message, "response body ended prematurely"
    end

    it "finishes cleanly when not framed (no Content-Length or Transfer-Encoding)" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\n\r\nhello",
        :eof
      ]
      unframed_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      unframed_timeout_class = fake(new: unframed_socket)
      unframed_opts = HTTP::Options.new(timeout_class: unframed_timeout_class)
      conn = HTTP::Connection.new(req, unframed_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      chunk = conn.readpartial

      assert_equal "hello", chunk
      # Should not raise premature EOF because body is not framed
      chunk2 = conn.readpartial

      assert_equal "", chunk2
    end

    it "finishes response when parser says finished (not just eof)" do
      # This tests the `eof || @parser.finished?` logic
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n",
        "hello",
        # After reading "hello", parser is finished (Content-Length satisfied)
        # even if we haven't seen :eof yet
        "more data that shouldn't matter",
        :eof
      ]
      pf_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      pf_timeout_class = fake(new: pf_socket)
      pf_opts = HTTP::Options.new(timeout_class: pf_timeout_class)
      conn = HTTP::Connection.new(req, pf_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      chunk = conn.readpartial

      assert_equal "hello", chunk
      # After reading exactly Content-Length bytes, parser.finished? should be true
      # and finish_response should be called
      assert_predicate conn, :finished_request?
    end

    it "returns binary empty string when parser has no data after read_more" do
      call_count = 0
      # Headers with no body data, then immediately EOF
      responses = [
        "HTTP/1.1 200 OK\r\n\r\n",
        :eof
      ]
      empty_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      empty_timeout_class = fake(new: empty_socket)
      empty_opts = HTTP::Options.new(timeout_class: empty_timeout_class)
      conn = HTTP::Connection.new(req, empty_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      chunk = conn.readpartial
      # Should return binary empty string "".b
      assert_equal Encoding::ASCII_8BIT, chunk.encoding
    end
  end

  # ---------------------------------------------------------------------------
  # #read_headers!
  # ---------------------------------------------------------------------------
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

    it "raises ResponseHeaderError on EOF before headers complete" do
      eof_socket = fake(connect: nil, close: nil, readpartial: :eof)
      eof_timeout_class = fake(new: eof_socket)
      eof_opts = HTTP::Options.new(timeout_class: eof_timeout_class)
      conn = HTTP::Connection.new(req, eof_opts)
      conn.instance_variable_set(:@pending_response, true)

      err = assert_raises(HTTP::ResponseHeaderError) { conn.read_headers! }
      assert_includes err.message, "couldn't read response headers"
    end

    it "calls set_keep_alive after reading headers" do
      raw_response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
      read_socket = fake(connect: nil, close: nil, readpartial: raw_response, closed?: false)
      read_timeout_class = fake(new: read_socket)
      read_opts = HTTP::Options.new(timeout_class: read_timeout_class)
      conn = HTTP::Connection.new(req, read_opts)
      conn.instance_variable_set(:@pending_response, true)
      conn.instance_variable_set(:@persistent, true)

      conn.read_headers!

      assert_predicate conn, :keep_alive?
    end

    it "passes BUFFER_SIZE to read_more" do
      # This tests that read_more is called with BUFFER_SIZE (not nil)
      read_sizes = []
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
        :eof
      ]
      bs_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc { |size, *|
          read_sizes << size
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        }
      )
      bs_timeout_class = fake(new: bs_socket)
      bs_opts = HTTP::Options.new(timeout_class: bs_timeout_class)
      conn = HTTP::Connection.new(req, bs_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!

      assert_includes read_sizes, HTTP::Connection::BUFFER_SIZE
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
    context "when a response is already pending (boolean)" do
      let(:socket) { fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize)) }

      it "closes the connection and proceeds" do
        connection.instance_variable_set(:@pending_response, true)
        new_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        connection.send_request(new_req)

        assert connection.instance_variable_get(:@pending_response)
      end
    end

    context "when a Response with large content_length is pending" do
      let(:socket) { fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize)) }

      it "closes the connection instead of flushing" do
        response = fake(content_length: HTTP::Connection::MAX_FLUSH_SIZE + 1, flush: nil)
        connection.instance_variable_set(:@pending_response, response)
        new_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        connection.send_request(new_req)

        assert connection.instance_variable_get(:@pending_response)
      end
    end

    context "when flushing the pending response raises" do
      let(:socket) { fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize)) }

      it "closes the connection and proceeds" do
        response = fake(content_length: nil, flush: -> { raise "boom" })
        connection.instance_variable_set(:@pending_response, response)
        new_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        connection.send_request(new_req)

        assert connection.instance_variable_get(:@pending_response)
      end
    end

    context "when a Response with small body is pending" do
      let(:socket) { fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize)) }

      it "flushes the response body" do
        flushed = false
        response = fake(content_length: 100, flush: -> { flushed = true })
        connection.instance_variable_set(:@pending_response, response)
        new_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        connection.send_request(new_req)

        assert flushed
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #finish_response
  # ---------------------------------------------------------------------------
  describe "#finish_response" do
    it "closes socket when not keeping alive" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
        :eof
      ]
      closed = false
      fr_socket = fake(
        connect:     nil,
        close:       -> { closed = true },
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     proc { closed }
      )
      fr_timeout_class = fake(new: fr_socket)
      fr_opts = HTTP::Options.new(timeout_class: fr_timeout_class)
      conn = HTTP::Connection.new(req, fr_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      conn.finish_response

      assert closed, "socket should be closed when not keep-alive"
      assert_predicate conn, :finished_request?
    end

    it "does not close socket when keeping alive" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
        :eof
      ]
      closed = false
      ka_socket = fake(
        connect:     nil,
        close:       -> { closed = true },
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     proc { closed }
      )
      ka_timeout_class = fake(new: ka_socket)
      ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class, keep_alive_timeout: 10)
      conn = HTTP::Connection.new(req, ka_opts)
      conn.instance_variable_set(:@pending_response, true)
      conn.instance_variable_set(:@persistent, true)

      conn.read_headers!

      assert_predicate conn, :keep_alive?
      conn.finish_response

      refute closed, "socket should NOT be closed when keep-alive"
      assert_predicate conn, :finished_request?
    end

    it "resets the parser for reuse" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
        :eof
      ]
      pr_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      pr_timeout_class = fake(new: pr_socket)
      pr_opts = HTTP::Options.new(timeout_class: pr_timeout_class)
      conn = HTTP::Connection.new(req, pr_opts)
      conn.instance_variable_set(:@pending_response, true)
      conn.instance_variable_set(:@persistent, true)

      conn.read_headers!

      assert_equal 200, conn.status_code

      conn.finish_response

      # Parser should be reset -- feeding new response should work
      parser = conn.instance_variable_get(:@parser)
      parser << "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"

      assert_equal 404, conn.status_code
    end

    it "calls reset_counter when socket responds to it" do
      counter_reset = false
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
        :eof
      ]
      rc_socket = fake(
        connect:       nil,
        close:         nil,
        readpartial:   proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:       false,
        reset_counter: -> { counter_reset = true }
      )
      rc_timeout_class = fake(new: rc_socket)
      rc_opts = HTTP::Options.new(timeout_class: rc_timeout_class)
      conn = HTTP::Connection.new(req, rc_opts)
      conn.instance_variable_set(:@pending_response, true)
      conn.instance_variable_set(:@persistent, true)

      conn.read_headers!
      conn.finish_response

      assert counter_reset, "reset_counter should have been called"
    end

    it "does not call reset_counter when socket does not respond to it" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
        :eof
      ]
      # Socket without reset_counter method
      no_rc_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      no_rc_timeout_class = fake(new: no_rc_socket)
      no_rc_opts = HTTP::Options.new(timeout_class: no_rc_timeout_class)
      conn = HTTP::Connection.new(req, no_rc_opts)
      conn.instance_variable_set(:@pending_response, true)
      conn.instance_variable_set(:@persistent, true)

      conn.read_headers!
      # Should not raise even though socket lacks reset_counter
      conn.finish_response

      assert_predicate conn, :finished_request?
    end

    it "resets timer for persistent connections" do
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
        :eof
      ]
      rt_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      rt_timeout_class = fake(new: rt_socket)
      rt_opts = HTTP::Options.new(timeout_class: rt_timeout_class, keep_alive_timeout: 30)
      conn = HTTP::Connection.new(req, rt_opts)
      conn.instance_variable_set(:@pending_response, true)
      conn.instance_variable_set(:@persistent, true)

      conn.read_headers!

      before = Time.now
      conn.finish_response
      after = Time.now

      expires = conn.instance_variable_get(:@conn_expires_at)

      assert_operator expires, :>=, before + 30
      assert_operator expires, :<=, after + 30
    end
  end

  # ---------------------------------------------------------------------------
  # #close
  # ---------------------------------------------------------------------------
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

    it "closes the socket and clears pending state" do
      closed = false
      close_socket = fake(
        connect: nil,
        close:   -> { closed = true },
        closed?: proc { closed }
      )
      close_timeout_class = fake(new: close_socket)
      close_opts = HTTP::Options.new(timeout_class: close_timeout_class)
      conn = HTTP::Connection.new(req, close_opts)
      conn.instance_variable_set(:@pending_response, true)
      conn.instance_variable_set(:@pending_request, true)

      conn.close

      assert closed, "socket should be closed"
      refute conn.instance_variable_get(:@pending_response)
      refute conn.instance_variable_get(:@pending_request)
    end

    it "does not close an already-closed socket" do
      close_count = 0
      already_closed_socket = fake(
        connect: nil,
        close:   -> { close_count += 1 },
        closed?: true
      )
      ac_timeout_class = fake(new: already_closed_socket)
      ac_opts = HTTP::Options.new(timeout_class: ac_timeout_class)
      conn = HTTP::Connection.new(req, ac_opts)

      conn.close

      assert_equal 0, close_count
    end
  end

  # ---------------------------------------------------------------------------
  # #finished_request?
  # ---------------------------------------------------------------------------
  describe "#finished_request?" do
    it "returns true when neither request nor response is pending" do
      assert_predicate connection, :finished_request?
    end

    it "returns false when pending_response is true" do
      connection.instance_variable_set(:@pending_response, true)

      refute_predicate connection, :finished_request?
    end

    it "returns false when pending_request is true" do
      connection.instance_variable_set(:@pending_request, true)

      refute_predicate connection, :finished_request?
    end

    it "returns false when both are true" do
      connection.instance_variable_set(:@pending_request, true)
      connection.instance_variable_set(:@pending_response, true)

      refute_predicate connection, :finished_request?
    end
  end

  # ---------------------------------------------------------------------------
  # #keep_alive?
  # ---------------------------------------------------------------------------
  describe "#keep_alive?" do
    it "returns false when keep_alive is false" do
      connection.instance_variable_set(:@keep_alive, false)

      refute_predicate connection, :keep_alive?
    end

    it "returns false when socket is closed" do
      closed_socket = fake(connect: nil, close: nil, closed?: true)
      closed_timeout_class = fake(new: closed_socket)
      closed_opts = HTTP::Options.new(timeout_class: closed_timeout_class)
      conn = HTTP::Connection.new(req, closed_opts)
      conn.instance_variable_set(:@keep_alive, true)

      refute_predicate conn, :keep_alive?
    end

    it "returns true when keep_alive is true and socket is open" do
      open_socket = fake(connect: nil, close: nil, closed?: false)
      open_timeout_class = fake(new: open_socket)
      open_opts = HTTP::Options.new(timeout_class: open_timeout_class)
      conn = HTTP::Connection.new(req, open_opts)
      conn.instance_variable_set(:@keep_alive, true)

      assert_predicate conn, :keep_alive?
    end
  end

  # ---------------------------------------------------------------------------
  # #expired?
  # ---------------------------------------------------------------------------
  describe "#expired?" do
    it "returns true when conn_expires_at is nil (non-persistent)" do
      assert_predicate connection, :expired?
    end

    it "returns true when connection has expired" do
      connection.instance_variable_set(:@conn_expires_at, Time.now - 1)

      assert_predicate connection, :expired?
    end

    it "returns false when connection has not expired" do
      connection.instance_variable_set(:@conn_expires_at, Time.now + 60)

      refute_predicate connection, :expired?
    end
  end

  # ---------------------------------------------------------------------------
  # keep_alive behavior (set_keep_alive)
  # ---------------------------------------------------------------------------
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

    context "with HTTP/1.0 without Keep-Alive header" do
      it "does not keep the connection alive" do
        response = "HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK"
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

    context "with HTTP/1.1 and no Connection header" do
      it "keeps the connection alive" do
        response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
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

    context "when not persistent" do
      it "sets keep_alive to false regardless of headers" do
        response = "HTTP/1.1 200 OK\r\nConnection: Keep-Alive\r\nContent-Length: 2\r\n\r\nOK"
        ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
        ka_timeout_class = fake(new: ka_socket)
        ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
        conn = HTTP::Connection.new(req, ka_opts)
        conn.instance_variable_set(:@pending_response, true)

        conn.read_headers!

        refute_predicate conn, :keep_alive?
      end
    end
  end

  # ---------------------------------------------------------------------------
  # proxy connect
  # ---------------------------------------------------------------------------
  describe "proxy connect" do
    let(:proxy_req) do
      HTTP::Request.new(
        verb:    :get,
        uri:     "https://example.com/",
        headers: {},
        proxy:   { proxy_address: "proxy.example.com", proxy_port: 8080 }
      )
    end

    context "when proxy returns non-200 status" do
      it "marks proxy connect as failed and stores proxy headers" do
        proxy_response = "HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic\r\n\r\n"
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
        conn = HTTP::Connection.new(proxy_req, proxy_opts)

        assert_predicate conn, :failed_proxy_connect?
        assert_instance_of HTTP::Headers, conn.proxy_response_headers
        assert_equal "Basic", conn.proxy_response_headers["Proxy-Authenticate"]
        # pending_response should still be true (not reset on failure)
        assert conn.instance_variable_get(:@pending_response)
      end
    end

    context "when proxy returns 200" do
      it "completes proxy connect successfully and resets parser" do
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
        conn = HTTP::Connection.new(proxy_req, proxy_opts)

        refute_predicate conn, :failed_proxy_connect?
        assert_instance_of HTTP::Headers, conn.proxy_response_headers
        # Parser should have been reset, pending_response should be false
        assert_predicate conn, :finished_request?
      end
    end

    context "when request is HTTP (not HTTPS)" do
      it "skips proxy connect" do
        http_proxy_req = HTTP::Request.new(
          verb:    :get,
          uri:     "http://example.com/",
          headers: {},
          proxy:   { proxy_address: "proxy.example.com", proxy_port: 8080 }
        )
        connect_called = false
        plain_socket = fake(
          connect:             nil,
          close:               nil,
          connect_using_proxy: ->(*) { connect_called = true }
        )
        plain_timeout_class = fake(new: plain_socket)
        plain_opts = HTTP::Options.new(timeout_class: plain_timeout_class)
        conn = HTTP::Connection.new(http_proxy_req, plain_opts)

        refute connect_called
        refute_predicate conn, :failed_proxy_connect?
      end
    end
  end

  # ---------------------------------------------------------------------------
  # start_tls
  # ---------------------------------------------------------------------------
  describe "start_tls" do
    it "uses provided ssl_context without creating a new one" do
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

    it "creates ssl_context and calls set_params when not provided" do
      https_req = HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})

      start_tls_args = nil
      tls_socket = fake(
        connect:   nil,
        close:     nil,
        start_tls: ->(*args) { start_tls_args = args }
      )
      tls_timeout_class = fake(new: tls_socket)
      tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class)

      HTTP::Connection.new(https_req, tls_opts)

      assert_equal "example.com", start_tls_args[0]
      assert_instance_of OpenSSL::SSL::SSLContext, start_tls_args[2]
    end

    it "passes ssl_socket_class to start_tls" do
      https_req = HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})

      start_tls_args = nil
      tls_socket = fake(
        connect:   nil,
        close:     nil,
        start_tls: ->(*args) { start_tls_args = args }
      )
      tls_timeout_class = fake(new: tls_socket)
      custom_ssl_class = Class.new
      tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class, ssl_socket_class: custom_ssl_class)

      HTTP::Connection.new(https_req, tls_opts)

      assert_equal custom_ssl_class, start_tls_args[1]
    end

    it "passes host from req.uri.host (not req.host)" do
      https_req = HTTP::Request.new(verb: :get, uri: "https://subdomain.example.com/", headers: {})

      start_tls_args = nil
      tls_socket = fake(
        connect:   nil,
        close:     nil,
        start_tls: ->(*args) { start_tls_args = args }
      )
      tls_timeout_class = fake(new: tls_socket)
      tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class)

      HTTP::Connection.new(https_req, tls_opts)

      assert_equal "subdomain.example.com", start_tls_args[0]
    end

    it "skips TLS for HTTP requests" do
      http_req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
      start_tls_called = false
      no_tls_socket = fake(
        connect:   nil,
        close:     nil,
        start_tls: ->(*) { start_tls_called = true }
      )
      no_tls_timeout_class = fake(new: no_tls_socket)
      no_tls_opts = HTTP::Options.new(timeout_class: no_tls_timeout_class)

      HTTP::Connection.new(http_req, no_tls_opts)

      refute start_tls_called
    end

    it "skips TLS when proxy connect failed" do
      proxy_req = HTTP::Request.new(
        verb:    :get,
        uri:     "https://example.com/",
        headers: {},
        proxy:   { proxy_address: "proxy.example.com", proxy_port: 8080 }
      )
      proxy_response = "HTTP/1.1 407 Auth Required\r\nContent-Length: 0\r\n\r\n"
      call_count = 0
      start_tls_called = false
      proxy_socket = fake(
        connect:     nil,
        close:       nil,
        write:       lambda(&:bytesize),
        readpartial: proc {
          call_count += 1
          call_count == 1 ? proxy_response : :eof
        },
        start_tls:   ->(*) { start_tls_called = true }
      )
      proxy_timeout_class = fake(new: proxy_socket)
      proxy_opts = HTTP::Options.new(timeout_class: proxy_timeout_class)

      conn = HTTP::Connection.new(proxy_req, proxy_opts)

      assert_predicate conn, :failed_proxy_connect?
      refute start_tls_called
    end

    it "applies ssl options via set_params when no ssl_context" do
      https_req = HTTP::Request.new(verb: :get, uri: "https://example.com/", headers: {})

      start_tls_args = nil
      tls_socket = fake(
        connect:   nil,
        close:     nil,
        start_tls: ->(*args) { start_tls_args = args }
      )
      tls_timeout_class = fake(new: tls_socket)
      ssl_options = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class, ssl: ssl_options)

      HTTP::Connection.new(https_req, tls_opts)

      ctx = start_tls_args[2]

      assert_instance_of OpenSSL::SSL::SSLContext, ctx
      assert_equal OpenSSL::SSL::VERIFY_NONE, ctx.verify_mode
    end
  end

  # ---------------------------------------------------------------------------
  # read_more and error handling
  # ---------------------------------------------------------------------------
  describe "read_more" do
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

    it "raises SocketReadError on IO errors during read" do
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
      err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
      assert_includes err.message, "error reading from socket"
      assert_includes err.message, "broken"
    end

    it "raises SocketReadError on SocketError during read" do
      call_count = 0
      rm_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc {
          call_count += 1
          raise SocketError, "socket error" unless call_count == 1

          "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
        }
      )
      rm_timeout_class = fake(new: rm_socket)
      rm_opts = HTTP::Options.new(timeout_class: rm_timeout_class)
      conn = HTTP::Connection.new(req, rm_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
      assert_includes err.message, "error reading from socket"
      assert_includes err.message, "socket error"
    end

    it "passes buffer to socket.readpartial" do
      read_args = []
      call_count = 0
      responses = [
        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n",
        "hello",
        :eof
      ]
      buf_socket = fake(
        connect:     nil,
        close:       nil,
        readpartial: proc { |*args|
          read_args << args
          idx = [call_count, responses.length - 1].min
          responses[idx].tap { call_count += 1 }
        },
        closed?:     false
      )
      buf_timeout_class = fake(new: buf_socket)
      buf_opts = HTTP::Options.new(timeout_class: buf_timeout_class)
      conn = HTTP::Connection.new(req, buf_opts)
      conn.instance_variable_set(:@pending_response, true)

      conn.read_headers!
      conn.readpartial

      # Verify that readpartial was called with 2 arguments (size + buffer)
      assert(read_args.all? { |a| a.length == 2 }, "readpartial should receive size and buffer")
      # Verify the buffer is a string (not nil)
      assert(read_args.all? { |a| a[1].is_a?(String) }, "buffer should be a String")
    end
  end

  # ---------------------------------------------------------------------------
  # connect_socket
  # ---------------------------------------------------------------------------
  describe "connect_socket" do
    it "passes correct arguments to socket.connect" do
      connect_args = nil
      connect_kwargs = nil
      cs_socket = fake(
        connect: lambda { |*args, **kwargs|
          connect_args = args
          connect_kwargs = kwargs
        },
        close:   nil
      )
      cs_timeout_class = fake(new: cs_socket)
      cs_opts = HTTP::Options.new(timeout_class: cs_timeout_class)

      HTTP::Connection.new(req, cs_opts)

      assert_equal HTTP::Options.default_socket_class, connect_args[0]
      assert_equal "example.com", connect_args[1]
      assert_equal 80, connect_args[2]
      refute connect_kwargs.fetch(:nodelay)
    end

    it "passes timeout_options to timeout_class.new" do
      new_kwargs = nil
      cs_socket = fake(connect: nil, close: nil)
      cs_timeout_class = fake(
        new: lambda { |**kwargs|
          new_kwargs = kwargs
          cs_socket
        }
      )
      cs_opts = HTTP::Options.new(timeout_class: cs_timeout_class)

      HTTP::Connection.new(req, cs_opts)

      assert_instance_of Hash, new_kwargs
    end

    it "calls reset_timer during initialization" do
      persist_socket = fake(connect: nil, close: nil)
      persist_timeout_class = fake(new: persist_socket)
      persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, keep_alive_timeout: 5)
      conn = HTTP::Connection.new(req, persist_opts)
      conn.instance_variable_set(:@persistent, true)

      # For persistent connections, reset_timer should set @conn_expires_at
      before = Time.now
      conn.send(:reset_timer)
      after = Time.now

      expires = conn.instance_variable_get(:@conn_expires_at)

      assert_operator expires, :>=, before + 5
      assert_operator expires, :<=, after + 5
    end
  end

  # ---------------------------------------------------------------------------
  # reset_timer
  # ---------------------------------------------------------------------------
  describe "reset_timer" do
    it "sets conn_expires_at for persistent connections" do
      persist_socket = fake(connect: nil, close: nil)
      persist_timeout_class = fake(new: persist_socket)
      persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, keep_alive_timeout: 5)
      conn = HTTP::Connection.new(req, persist_opts)
      conn.instance_variable_set(:@persistent, true)

      before = Time.now
      conn.send(:reset_timer)
      after = Time.now

      expires = conn.instance_variable_get(:@conn_expires_at)

      assert_operator expires, :>=, before + 5
      assert_operator expires, :<=, after + 5
    end

    it "does not set conn_expires_at for non-persistent connections" do
      conn = connection
      conn.instance_variable_set(:@conn_expires_at, nil)
      conn.send(:reset_timer)

      assert_nil conn.instance_variable_get(:@conn_expires_at)
    end

    it "uses keep_alive_timeout from options" do
      persist_socket = fake(connect: nil, close: nil)
      persist_timeout_class = fake(new: persist_socket)
      persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, keep_alive_timeout: 42)
      conn = HTTP::Connection.new(req, persist_opts)
      conn.instance_variable_set(:@persistent, true)

      before = Time.now
      conn.send(:reset_timer)

      expires = conn.instance_variable_get(:@conn_expires_at)
      # Should be approximately now + 42
      assert_operator expires, :>=, before + 42
      assert_operator expires, :<, before + 43
    end
  end

  # ---------------------------------------------------------------------------
  # init_state
  # ---------------------------------------------------------------------------
  describe "init_state" do
    it "stores persistent flag from options" do
      persist_socket = fake(connect: nil, close: nil)
      persist_timeout_class = fake(new: persist_socket)
      persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, persistent: "http://example.com")
      conn = HTTP::Connection.new(req, persist_opts)

      assert conn.instance_variable_get(:@persistent)
    end

    it "stores keep_alive_timeout as float" do
      kat = connection.instance_variable_get(:@keep_alive_timeout)

      assert_instance_of Float, kat
    end

    it "initializes buffer as binary empty string" do
      buf = connection.instance_variable_get(:@buffer)

      assert_equal "".b, buf
      assert_equal Encoding::ASCII_8BIT, buf.encoding
    end

    it "initializes parser" do
      parser = connection.instance_variable_get(:@parser)

      assert_instance_of HTTP::Response::Parser, parser
    end
  end
end
