# frozen_string_literal: true

require "test_helper"

describe HTTP::Request::Writer do
  cover "HTTP::Request::Writer*"
  let(:writer)      { HTTP::Request::Writer.new(io, body, headers, headerstart) }

  let(:io)          { StringIO.new }
  let(:body)        { HTTP::Request::Body.new("") }
  let(:headers)     { HTTP::Headers.new }
  let(:headerstart) { "GET /test HTTP/1.1" }

  describe "#stream" do
    context "when multiple headers are set" do
      let(:headers) { HTTP::Headers.coerce "Host" => "example.org" }

      it "separates headers with carriage return and line feed" do
        writer.stream

        assert_equal [
          "#{headerstart}\r\n",
          "Host: example.org\r\nContent-Length: 0\r\n\r\n"
        ].join, io.string
      end
    end

    context "when headers are specified as strings with mixed case" do
      let(:headers) { HTTP::Headers.coerce "content-Type" => "text", "X_MAX" => "200" }

      it "writes the headers with the same casing" do
        writer.stream

        assert_equal [
          "#{headerstart}\r\n",
          "content-Type: text\r\nX_MAX: 200\r\nContent-Length: 0\r\n\r\n"
        ].join, io.string
      end
    end

    context "when body is nonempty" do
      let(:body) { HTTP::Request::Body.new("content") }

      it "writes it to the socket and sets Content-Length" do
        writer.stream

        assert_equal [
          "#{headerstart}\r\n",
          "Content-Length: 7\r\n\r\n",
          "content"
        ].join, io.string
      end
    end

    context "when body is not set" do
      let(:body) { HTTP::Request::Body.new(nil) }

      it "doesn't write anything to the socket and doesn't set Content-Length" do
        writer.stream

        assert_equal "#{headerstart}\r\n\r\n", io.string
      end
    end

    context "when body is empty" do
      let(:body) { HTTP::Request::Body.new("") }

      it "doesn't write anything to the socket and sets Content-Length" do
        writer.stream

        assert_equal [
          "#{headerstart}\r\n",
          "Content-Length: 0\r\n\r\n"
        ].join, io.string
      end
    end

    context "when Content-Length header is set" do
      let(:headers) { HTTP::Headers.coerce "Content-Length" => "12" }
      let(:body)    { HTTP::Request::Body.new("content") }

      it "keeps the given value" do
        writer.stream

        assert_equal [
          "#{headerstart}\r\n",
          "Content-Length: 12\r\n\r\n",
          "content"
        ].join, io.string
      end
    end

    context "when Transfer-Encoding is chunked" do
      let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "chunked" }
      let(:body)    { HTTP::Request::Body.new(%w[request body]) }

      it "writes encoded content and omits Content-Length" do
        writer.stream

        assert_equal [
          "#{headerstart}\r\n",
          "Transfer-Encoding: chunked\r\n\r\n",
          "7\r\nrequest\r\n4\r\nbody\r\n0\r\n\r\n"
        ].join, io.string
      end
    end

    context "when Transfer-Encoding is chunked with body size >= 10" do
      let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "chunked" }
      let(:body)    { HTTP::Request::Body.new(["a" * 255]) }

      it "encodes chunk size in hexadecimal" do
        writer.stream

        assert_includes io.string, "ff\r\n#{'a' * 255}\r\n"
      end
    end

    context "when Transfer-Encoding is not chunked" do
      let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "gzip" }
      let(:body)    { HTTP::Request::Body.new("content") }

      it "does not treat as chunked encoding" do
        writer.stream

        refute_includes io.string, "0\r\n\r\n"
        assert_includes io.string, "content"
      end

      it "returns false from chunked?" do
        refute_predicate writer, :chunked?
      end
    end

    context "when server won't accept any more data" do
      it "aborts silently" do
        mock_io = Object.new
        mock_io.define_singleton_method(:write) { |*| raise Errno::EPIPE }
        w = HTTP::Request::Writer.new(mock_io, body, headers, headerstart)
        w.stream
      end
    end

    context "when body is nil on a POST request" do
      let(:headerstart) { "POST /test HTTP/1.1" }
      let(:body)        { HTTP::Request::Body.new(nil) }

      it "sets Content-Length to 0" do
        writer.stream

        assert_equal "POST /test HTTP/1.1\r\nContent-Length: 0\r\n\r\n", io.string
      end
    end

    context "when body is nil on a HEAD request" do
      let(:headerstart) { "HEAD /test HTTP/1.1" }
      let(:headers)     { HTTP::Headers.coerce "Host" => "example.org" }
      let(:body)        { HTTP::Request::Body.new(nil) }

      it "omits Content-Length" do
        writer.stream

        refute_includes io.string, "Content-Length"
      end
    end

    context "when body is nil on a DELETE request" do
      let(:headerstart) { "DELETE /test HTTP/1.1" }
      let(:headers)     { HTTP::Headers.coerce "Host" => "example.org" }
      let(:body)        { HTTP::Request::Body.new(nil) }

      it "omits Content-Length" do
        writer.stream

        refute_includes io.string, "Content-Length"
      end
    end

    context "when body is nil on a CONNECT request" do
      let(:headerstart) { "CONNECT example.com:443 HTTP/1.1" }
      let(:headers)     { HTTP::Headers.coerce "Host" => "example.com:443" }
      let(:body)        { HTTP::Request::Body.new(nil) }

      it "omits Content-Length" do
        writer.stream

        refute_includes io.string, "Content-Length"
      end
    end

    context "when writing to socket raises an exception" do
      it "raises a ConnectionError" do
        mock_io = Object.new
        mock_io.define_singleton_method(:write) { |*| raise Errno::ECONNRESET }
        w = HTTP::Request::Writer.new(mock_io, body, headers, headerstart)
        assert_raises(HTTP::ConnectionError) { w.stream }
      end

      it "includes original error message" do
        mock_io = Object.new
        mock_io.define_singleton_method(:write) { |*| raise Errno::ECONNRESET }
        w = HTTP::Request::Writer.new(mock_io, body, headers, headerstart)
        err = assert_raises(HTTP::ConnectionError) { w.stream }

        assert_includes err.message, "error writing to socket:"
        assert_includes err.message, "Connection reset by peer"
      end

      it "preserves original error backtrace" do
        mock_io = Object.new
        mock_io.define_singleton_method(:write) { |*| raise Errno::ECONNRESET }
        w = HTTP::Request::Writer.new(mock_io, body, headers, headerstart)
        err = assert_raises(HTTP::ConnectionError) { w.stream }

        assert_includes err.backtrace.first, "writer_test.rb"
      end
    end

    context "when socket performs partial writes" do
      it "writes remaining data in subsequent calls" do
        written = []
        call_count = 0
        mock_io = Object.new
        mock_io.define_singleton_method(:write) do |data|
          call_count += 1
          bytes = call_count == 1 ? [5, data.bytesize].min : data.bytesize
          written << data.byteslice(0, bytes)
          bytes
        end

        body = HTTP::Request::Body.new("HelloWorld")
        w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, headerstart)
        w.stream

        full_output = written.join

        assert_includes full_output, "HelloWorld"
      end
    end
  end

  describe "#connect_through_proxy" do
    it "writes headers without body" do
      writer.connect_through_proxy

      assert_equal "GET /test HTTP/1.1\r\n\r\n", io.string
    end

    context "with headers" do
      let(:headers) { HTTP::Headers.coerce "Host" => "example.org" }

      it "includes headers in the output" do
        writer.connect_through_proxy

        assert_equal "GET /test HTTP/1.1\r\nHost: example.org\r\n\r\n", io.string
      end
    end

    context "when socket raises EPIPE" do
      it "propagates the error" do
        mock_io = Object.new
        mock_io.define_singleton_method(:write) { |*| raise Errno::EPIPE }
        w = HTTP::Request::Writer.new(mock_io, body, headers, headerstart)

        assert_raises(Errno::EPIPE) { w.connect_through_proxy }
      end
    end
  end

  describe "#each_chunk" do
    context "when body has content" do
      let(:body) { HTTP::Request::Body.new("content") }

      it "yields headers combined with first chunk" do
        writer.add_headers
        writer.add_body_type_headers
        chunks = []
        writer.each_chunk { |chunk| chunks << chunk.dup }

        assert_equal 1, chunks.length
        assert_includes chunks.first, "content"
      end
    end

    context "when body is empty" do
      let(:body) { HTTP::Request::Body.new("") }

      it "yields headers only once" do
        writer.add_headers
        writer.add_body_type_headers
        chunks = []
        writer.each_chunk { |chunk| chunks << chunk.dup }

        assert_equal 1, chunks.length
        assert_includes chunks.first, headerstart
      end
    end
  end

  describe "#add_body_type_headers" do
    # Kills mutations:
    # - @request_header[0] -> @request_header.at(0)
    # - @request_header[0] -> @request_header.fetch(0)
    # Both are equivalent for arrays, so these are namespace-equivalent mutations.
    context "when body is nil on a PUT request" do
      let(:headerstart) { "PUT /test HTTP/1.1" }
      let(:body)        { HTTP::Request::Body.new(nil) }

      it "sets Content-Length to 0" do
        writer.stream

        assert_includes io.string, "Content-Length: 0"
      end
    end

    context "when body is nil on a PATCH request" do
      let(:headerstart) { "PATCH /test HTTP/1.1" }
      let(:body)        { HTTP::Request::Body.new(nil) }

      it "sets Content-Length to 0" do
        writer.stream

        assert_includes io.string, "Content-Length: 0"
      end
    end

    context "when body is nil on an OPTIONS request" do
      let(:headerstart) { "OPTIONS /test HTTP/1.1" }
      let(:body)        { HTTP::Request::Body.new(nil) }

      it "sets Content-Length to 0" do
        writer.stream

        assert_includes io.string, "Content-Length: 0"
      end
    end
  end

  describe "#write (private) partial write handling" do
    # Kills mutations on the write method's loop:
    # - until data.empty? -> until nil / until false
    # - unless data.bytesize > length -> unless length / unless true / unless data.bytesize
    # - removing the break / unless block
    # - data = data.byteslice(length..-1) -> data = data / data.byteslice(nil..-1) / data.byteslice(length..nil)
    # - break -> nil
    context "when socket performs partial writes" do
      it "writes exactly the correct bytes with no duplication or loss" do
        # Track every byte written to the socket
        written_data = +""
        write_calls = 0
        mock_io = Object.new
        mock_io.define_singleton_method(:write) do |data|
          write_calls += 1
          # Only write 2 bytes per call to force multiple iterations
          bytes = [2, data.bytesize].min
          written_data << data.byteslice(0, bytes)
          bytes
        end

        # Use a known body so we can verify exact output
        body = HTTP::Request::Body.new("ABCDEF")
        w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, headerstart)
        w.stream

        # The full output should contain the headers + body exactly once
        assert_includes written_data, "ABCDEF"
        # Body should appear exactly once (no duplication from loop bugs)
        body_start = written_data.index("ABCDEF")

        refute_nil body_start
        assert_nil written_data.index("ABCDEF", body_start + 1)
        # Multiple write calls are needed due to partial writes
        assert_operator write_calls, :>, 1
      end
    end

    context "when socket writes all bytes at once" do
      it "calls write only once per data chunk" do
        write_calls = 0
        mock_io = Object.new
        mock_io.define_singleton_method(:write) do |data|
          write_calls += 1
          data.bytesize
        end

        body = HTTP::Request::Body.new("Hello")
        w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, headerstart)
        w.stream

        # Should write only once since all bytes were accepted
        assert_equal 1, write_calls
      end
    end

    context "when data is split across exactly two writes" do
      it "correctly slices remaining data after first partial write" do
        written_chunks = []
        call_count = 0
        mock_io = Object.new
        mock_io.define_singleton_method(:write) do |data|
          call_count += 1
          written_chunks << data.dup
          if call_count == 1
            # Write only 5 bytes of the first chunk (headers + body combined)
            [5, data.bytesize].min
          else
            data.bytesize
          end
        end

        body = HTTP::Request::Body.new("TESTDATA123")
        w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, headerstart)
        w.stream

        full_output = written_chunks.map { |c| c.byteslice(0, [5, c.bytesize].min) }.first +
                      written_chunks[1..].join

        assert_includes full_output, "TESTDATA123"
        # Second call should have the REMAINDER, not the full data
        assert_operator written_chunks[1].bytesize, :<, written_chunks[0].bytesize
      end
    end
  end
end
