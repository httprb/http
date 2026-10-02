# frozen_string_literal: true

RSpec.describe HTTP::Connection do
  let(:req) do
    HTTP::Request.new(
      :verb    => :get,
      :uri     => "http://example.com/",
      :headers => {}
    )
  end
  let(:socket) { double(:connect => nil, :close => nil) }
  let(:timeout_class) { double(:new => socket) }
  let(:opts) { HTTP::Options.new(:timeout_class => timeout_class) }
  let(:connection) { HTTP::Connection.new(req, opts) }

  describe "#initialize times out" do
    let(:req) do
      HTTP::Request.new(
        :verb    => :get,
        :uri     => "https://example.com/",
        :headers => {}
      )
    end

    before do
      expect(socket).to receive(:start_tls).and_raise(HTTP::TimeoutError)
      expect(socket).to receive(:closed?) { false }
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
        <<-RESPONSE.gsub(/^\s*\| */, "").gsub(/\n/, "\r\n")
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

  describe "#readpartial" do
    before do
      connection.instance_variable_set(:@pending_response, true)
      expect(socket).to receive(:readpartial) do
        <<-RESPONSE.gsub(/^\s*\| */, "").gsub(/\n/, "\r\n")
        | HTTP/1.1 200 OK
        | Content-Type: text
        |
        RESPONSE
      end
      expect(socket).to receive(:readpartial) { "1" }
      expect(socket).to receive(:readpartial) { "23" }
      expect(socket).to receive(:readpartial) { "456" }
      expect(socket).to receive(:readpartial) { "78" }
      expect(socket).to receive(:readpartial) { "9" }
      expect(socket).to receive(:readpartial) { "0" }
      expect(socket).to receive(:readpartial) { :eof }
      expect(socket).to receive(:closed?) { true }
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

  describe "#stale?" do
    let(:pair) { UNIXSocket.pair }
    let(:io) { pair.first }
    let(:peer) { pair.last }
    let(:socket) { double(:connect => nil, :close => nil, :socket => io) }

    after { pair.each { |s| s.close unless s.closed? } }

    it "is false while the idle peer is still there" do
      expect(connection.stale?).to be false
    end

    it "is true once the peer closed the idle connection" do
      peer.close
      expect(connection.stale?).to be true
    end

    it "is true once the peer sent data on the idle connection" do
      peer.write("HTTP/1.1 408 Request Timeout\r\nContent-Length: 0\r\n\r\n")
      expect(connection.stale?).to be true
    end

    it "is false while a response is pending, because its body is expected data" do
      peer.write("unread body")
      connection.instance_variable_set(:@pending_response, true)
      expect(connection.stale?).to be false
    end

    it "is true when the socket is already closed" do
      io.close
      expect(connection.stale?).to be true
    end

    context "when the timeout class doesn't expose its socket" do
      let(:socket) { double(:connect => nil, :close => nil) }

      it "is false" do
        expect(connection.stale?).to be false
      end
    end

    context "when the exposed socket isn't an IO" do
      let(:socket) { double(:connect => nil, :close => nil, :socket => Object.new) }

      it "is false" do
        expect(connection.stale?).to be false
      end
    end
  end
end
