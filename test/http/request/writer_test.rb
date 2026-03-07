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

    context "when writing to socket raises an exception" do
      it "raises a ConnectionError" do
        mock_io = Object.new
        mock_io.define_singleton_method(:write) { |*| raise Errno::ECONNRESET }
        w = HTTP::Request::Writer.new(mock_io, body, headers, headerstart)
        assert_raises(HTTP::ConnectionError) { w.stream }
      end
    end
  end

  describe "#connect_through_proxy" do
    it "writes headers without body" do
      writer.connect_through_proxy

      assert_equal "GET /test HTTP/1.1\r\n\r\n", io.string
    end
  end
end
