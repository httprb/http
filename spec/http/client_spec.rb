require 'spec_helper'

describe HTTP::Client do
  StubbedClient = Class.new(HTTP::Client) do
    def perform(request, options)
      stubs.fetch(request.uri.to_s) { super(request, options) }
    end

    def stubs
      @stubs ||= {}
    end

    def stub(stubs)
      @stubs = stubs
      self
    end
  end

  def redirect_response(location, status = 302)
    HTTP::Response.new(status, '1.1', {'Location' => location}, '')
  end

  def simple_response(body, status = 200)
    HTTP::Response.new(status, '1.1', {}, body)
  end

  describe 'following redirects' do
    it 'returns response of new location' do
      client = StubbedClient.new(:follow => true).stub(
        'http://example.com/'     => redirect_response('http://example.com/blog'),
        'http://example.com/blog' => simple_response('OK')
      )

      expect(client.get('http://example.com/').to_s).to eq 'OK'
    end

    it 'prepends previous request uri scheme and host if needed' do
      client = StubbedClient.new(:follow => true).stub(
        'http://example.com/'           => redirect_response('/index'),
        'http://example.com/index'      => redirect_response('/index.html'),
        'http://example.com/index.html' => simple_response('OK')
      )

      expect(client.get('http://example.com/').to_s).to eq 'OK'
    end

    it 'fails upon endless redirects' do
      client = StubbedClient.new(:follow => true).stub(
        'http://example.com/' => redirect_response('/')
      )

      expect { client.get('http://example.com/') } \
        .to raise_error(HTTP::Redirector::EndlessRedirectError)
    end

    it 'fails if max amount of hops reached' do
      client = StubbedClient.new(:follow => 5).stub(
        'http://example.com/'  => redirect_response('/1'),
        'http://example.com/1' => redirect_response('/2'),
        'http://example.com/2' => redirect_response('/3'),
        'http://example.com/3' => redirect_response('/4'),
        'http://example.com/4' => redirect_response('/5'),
        'http://example.com/5' => redirect_response('/6'),
        'http://example.com/6' => simple_response('OK')
      )

      expect { client.get('http://example.com/') } \
        .to raise_error(HTTP::Redirector::TooManyRedirectsError)
    end
  end

  describe 'parsing params' do
    let(:client) { HTTP::Client.new }
    before { allow(client).to receive :perform }

    it 'accepts params within the provided URL' do
      expect(HTTP::Request).to receive(:new) do |_, uri|
        expect(CGI.parse uri.query).to eq('foo' => %w[bar])
      end

      client.get('http://example.com/?foo=bar')
    end

    it 'combines GET params from the URI with the passed in params' do
      expect(HTTP::Request).to receive(:new) do |_, uri|
        expect(CGI.parse uri.query).to eq('foo' => %w[bar], 'baz' => %w[quux])
      end

      client.get('http://example.com/?foo=bar', :params => {:baz => 'quux'})
    end

    it 'merges duplicate values' do
      expect(HTTP::Request).to receive(:new) do |_, uri|
        expect(uri.query).to match(/^(a=1&a=2|a=2&a=1)$/)
      end

      client.get('http://example.com/?a=1', :params => {:a => 2})
    end

    it 'does not modifies query part if no params were given' do
      expect(HTTP::Request).to receive(:new) do |_, uri|
        expect(uri.query).to eq 'deadbeef'
      end

      client.get('http://example.com/?deadbeef')
    end

    it 'does not corrupts index-less arrays' do
      expect(HTTP::Request).to receive(:new) do |_, uri|
        expect(CGI.parse uri.query).to eq 'a[]' => %w[b c], 'd' => %w[e]
      end

      client.get('http://example.com/?a[]=b&a[]=c', :params => {:d => 'e'})
    end
  end

  describe 'passing json' do
    it 'encodes given object' do
      client = HTTP::Client.new
      allow(client).to receive(:perform)

      expect(HTTP::Request).to receive(:new) do |*args|
        expect(args.last).to eq('{"foo":"bar"}')
      end

      client.get('http://example.com/', :json => {:foo => :bar})
    end
  end

  describe '#request' do
    context 'with explicitly given `Host` header' do
      let(:headers) { {'Host' => 'another.example.com'} }
      let(:client)  { described_class.new :headers => headers }

      it 'keeps `Host` header as is' do
        expect(client).to receive(:perform) do |req, _|
          expect(req['Host']).to eq 'another.example.com'
        end

        client.request(:get, 'http://example.com/')
      end
    end
  end

  describe '#perform' do
    let(:client) { described_class.new }

    it 'calls finish_response before actual performance' do
      allow(TCPSocket).to receive(:open) { throw :halt }
      expect(client).to receive(:finish_response)
      catch(:halt) { client.head "http://127.0.0.1:#{ExampleService::PORT}/" }
    end

    it 'calls finish_response once body was fully flushed' do
      expect(client).to receive(:finish_response).twice.and_call_original
      client.get("http://127.0.0.1:#{ExampleService::PORT}/").to_s
    end

    context 'with HEAD request' do
      it 'does not iterates through body' do
        expect(client).to_not receive(:readpartial)
        client.head("http://127.0.0.1:#{ExampleService::PORT}/")
      end

      it 'finishes response after headers were received' do
        expect(client).to receive(:finish_response).twice.and_call_original
        client.head("http://127.0.0.1:#{ExampleService::PORT}/")
      end
    end

    context 'when server fully flushes response in one chunk' do
      before do
        socket_spy = double

        chunks = [
          <<-RESPONSE.gsub(/^\s*\| */, '').gsub(/\n/, "\r\n")
          | HTTP/1.1 200 OK
          | Content-Type: text/html
          | Server: WEBrick/1.3.1 (Ruby/1.9.3/2013-11-22)
          | Date: Mon, 24 Mar 2014 00:32:22 GMT
          | Content-Length: 15
          | Connection: Keep-Alive
          |
          | <!doctype html>
          RESPONSE
        ]

        allow(socket_spy).to receive(:close) { nil }
        allow(socket_spy).to receive(:closed?) { true }
        allow(socket_spy).to receive(:readpartial) { chunks.shift }
        allow(socket_spy).to receive(:<<) { nil }

        allow(TCPSocket).to receive(:open) { socket_spy }
      end

      it 'properly reads body' do
        body = client.get("http://127.0.0.1:#{ExampleService::PORT}/").to_s
        expect(body).to eq '<!doctype html>'
      end
    end
  end
end
