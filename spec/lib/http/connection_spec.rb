# frozen_string_literal: true

RSpec.describe HTTP::Connection do
  let(:req) do
    HTTP::Request.new(
      :verb    => :get,
      :uri     => "http://example.com/",
      :headers => {}
    )
  end
  let(:socket) { double(:connect => nil) }
  let(:timeout_class) { double(:new => socket) }
  let(:opts) { HTTP::Options.new(:timeout_class => timeout_class) }
  let(:connection) { HTTP::Connection.new(req, opts) }

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
        buffer << s
      end
      expect(buffer).to eq "1234567890"
    end
  end

  # Pattern Matching only exists in Ruby 2.7+, guard against execution of
  # tests otherwise
  if RUBY_VERSION >= '2.7'
    describe '#to_h' do
      it 'returns a Hash representation of a Connection' do
        expect(connection.to_h).to include({
          buffer: "",
          failed_proxy_connect: false,
          headers: a_kind_of(HTTP::Headers),
          http_version: "0.0",
          keep_alive_timeout: 5.0,
          parser: a_kind_of(HTTP::Response::Parser),
          pending_request: false,
          pending_response: false,
          persistent: false,
          socket: socket,
          status_code: 0,
        })
      end
    end

    describe 'Pattern Matching' do
      it 'can perform a pattern match' do
        # Cursed hack to ignore syntax errors to test Pattern Matching.
        value = eval <<~RUBY
          case connection
          in status_code: 0, pending_request: false
            true
          else
            false
          end
        RUBY

        expect(value).to eq(true)
      end
    end
  end
end
