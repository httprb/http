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
end
