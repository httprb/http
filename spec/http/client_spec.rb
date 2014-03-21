require 'spec_helper'

describe HTTP::Client do
  StubbedClient = Class.new(HTTP::Client) do
    def perform_without_following_redirects(request, options)
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
    it 'accepts params within the provided URL' do
      client = HTTP::Client.new
      allow(client).to receive(:perform)
      expect(HTTP::Request).to receive(:new) do |_, uri|
        params = CGI.parse(URI(uri).query)
        expect(params).to eq('foo' => ['bar'])
      end

      client.get('http://example.com/?foo=bar')
    end

    it 'combines GET params from the URI with the passed in params' do
      client = HTTP::Client.new
      allow(client).to receive(:perform)
      expect(HTTP::Request).to receive(:new) do |_, uri|
        params = CGI.parse(URI(uri).query)
        expect(params).to eq('foo' => ['bar'], 'baz' => ['quux'])
      end

      client.get('http://example.com/?foo=bar', :params => {:baz => 'quux'})
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
        expect(client).to receive(:perform) do |req, options|
          expect(req['Host']).to eq 'another.example.com'
        end

        client.request(:get, 'http://example.com/')
      end
    end
  end
end
