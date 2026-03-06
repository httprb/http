# frozen_string_literal: true

RSpec.describe HTTP::Connection do
  let(:req) do
    HTTP::Request.new(
      verb:    :get,
      uri:     "http://example.com/",
      headers: {}
    )
  end
  let(:socket) { double(connect: nil, close: nil) }
  let(:timeout_class) { double(new: socket) }
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

    before do
      expect(socket).to receive(:start_tls).and_raise(HTTP::TimeoutError)
      expect(socket).to receive(:closed?).and_return(false)
      expect(socket).to receive(:close)
    end

    it "closes the connection" do
      expect { connection }.to raise_error(HTTP::TimeoutError)
    end
  end

  describe "#read_headers!" do
    before do
      connection.instance_variable_set(:@pending_response, true)
      expect(socket).to receive(:readpartial) do
        <<-RESPONSE.gsub(/^\s*\| */, "").gsub("\n", "\r\n")
        | HTTP/1.1 200 OK
        | Content-Type: text
        | foo_bar: 123
        |
        RESPONSE
      end
    end

    it "populates headers collection, preserving casing" do
      connection.read_headers!
      expect(connection.headers).to eq("Content-Type" => "text", "foo_bar" => "123")
      expect(connection.headers["Foo-Bar"]).to eq("123")
      expect(connection.headers["foo_bar"]).to eq("123")
    end
  end

  describe "#send_request" do
    context "when a response is already pending" do
      before { connection.instance_variable_set(:@pending_response, true) }

      it "raises StateError" do
        req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        expect { connection.send_request(req) }.to raise_error(HTTP::StateError)
      end
    end

    context "when a request is already pending" do
      before { connection.instance_variable_set(:@pending_request, true) }

      it "raises StateError" do
        req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
        expect { connection.send_request(req) }.to raise_error(HTTP::StateError)
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
      before do
        proxy_response = "HTTP/1.1 407 Proxy Authentication Required\r\nContent-Length: 0\r\n\r\n"
        call_count = 0
        allow(socket).to receive(:write, &:bytesize)
        allow(socket).to receive(:readpartial) do
          call_count += 1
          call_count == 1 ? proxy_response : :eof
        end
        allow(socket).to receive(:start_tls)
      end

      it "marks proxy connect as failed" do
        expect(connection.failed_proxy_connect?).to be true
      end
    end

    context "when proxy returns 200" do
      before do
        proxy_response = "HTTP/1.1 200 Connection established\r\n\r\n"
        allow(socket).to receive(:write, &:bytesize)
        allow(socket).to receive(:readpartial).and_return(proxy_response)
        allow(socket).to receive(:start_tls)
        allow(socket).to receive(:hostname=)
        allow(socket).to receive(:sync_close=)
        allow(socket).to receive(:connect)
        allow(socket).to receive(:post_connection_check)
      end

      it "completes proxy connect successfully" do
        expect(connection.failed_proxy_connect?).to be false
      end
    end
  end

  describe "keep_alive behavior" do
    before do
      connection.instance_variable_set(:@pending_response, true)
      connection.instance_variable_set(:@persistent, true)
    end

    context "with HTTP/1.0 and Keep-Alive header" do
      before do
        response = "HTTP/1.0 200 OK\r\nConnection: Keep-Alive\r\nContent-Length: 2\r\n\r\nOK"
        expect(socket).to receive(:readpartial).and_return(response)
      end

      it "keeps the connection alive" do
        connection.read_headers!
        allow(socket).to receive(:closed?).and_return(false)
        expect(connection.keep_alive?).to be true
      end
    end

    context "with unknown HTTP version" do
      before do
        expect(socket).to receive(:readpartial).and_return("HTTP/2.0 200 OK\r\nContent-Length: 2\r\n\r\nOK")
      end

      it "does not keep the connection alive" do
        connection.read_headers!
        allow(socket).to receive(:closed?).and_return(false)
        expect(connection.keep_alive?).to be false
      end
    end

    context "with HTTP/1.1 and Connection: close" do
      before do
        response = "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\nOK"
        expect(socket).to receive(:readpartial).and_return(response)
      end

      it "does not keep the connection alive" do
        connection.read_headers!
        allow(socket).to receive(:closed?).and_return(false)
        expect(connection.keep_alive?).to be false
      end
    end
  end

  describe "read_more error handling" do
    before do
      connection.instance_variable_set(:@pending_response, true)
      expect(socket).to receive(:readpartial).and_return("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n")
    end

    it "raises SocketReadError on IO errors during read" do
      connection.read_headers!
      expect(socket).to receive(:readpartial).and_raise(IOError, "broken")
      expect { connection.readpartial }.to raise_error(HTTP::ConnectionError, /error reading from socket/)
    end
  end

  describe "#readpartial" do
    before do
      connection.instance_variable_set(:@pending_response, true)
      expect(socket).to receive(:readpartial) do
        <<-RESPONSE.gsub(/^\s*\| */, "").gsub("\n", "\r\n")
        | HTTP/1.1 200 OK
        | Content-Type: text
        |
        RESPONSE
      end
      expect(socket).to receive(:readpartial).and_return("1")
      expect(socket).to receive(:readpartial).and_return("23")
      expect(socket).to receive(:readpartial).and_return("456")
      expect(socket).to receive(:readpartial).and_return("78")
      expect(socket).to receive(:readpartial).and_return("9")
      expect(socket).to receive(:readpartial).and_return("0")
      expect(socket).to receive(:readpartial).and_return(:eof)
      expect(socket).to receive(:closed?).and_return(true)
    end

    it "reads data in parts" do
      connection.read_headers!
      buffer = String.new
      while (s = connection.readpartial(3))
        expect(connection.finished_request?).to be false if s != ""
        buffer << s
      end
      expect(buffer).to eq "1234567890"
      expect(connection.finished_request?).to be true
    end
  end
end
