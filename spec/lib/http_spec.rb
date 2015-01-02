require 'json'

RSpec.describe HTTP do
  let(:test_endpoint)  { "http://#{ExampleServer::ADDR}" }

  context 'getting resources' do
    it 'is easy' do
      response = HTTP.get test_endpoint
      expect(response.to_s).to match(/<!doctype html>/)
    end

    context 'with URI instance' do
      it 'is easy' do
        response = HTTP.get URI test_endpoint
        expect(response.to_s).to match(/<!doctype html>/)
      end
    end

    context 'with query string parameters' do
      it 'is easy' do
        response = HTTP.get "#{test_endpoint}/params", :params => {:foo => 'bar'}
        expect(response.to_s).to match(/Params!/)
      end
    end

    context 'with query string parameters in the URI and opts hash' do
      it 'includes both' do
        response = HTTP.get "#{test_endpoint}/multiple-params?foo=bar", :params => {:baz => 'quux'}
        expect(response.to_s).to match(/More Params!/)
      end
    end

    context 'with headers' do
      it 'is easy' do
        response = HTTP.accept('application/json').get test_endpoint
        expect(response.to_s.include?('json')).to be true
      end
    end
  end

  context 'with http proxy address and port' do
    it 'proxies the request' do
      response = HTTP.via('127.0.0.1', 8080).get test_endpoint
      expect(response.headers['X-Proxied']).to eq 'true'
    end
  end

  context 'with http proxy address, port username and password' do
    it 'proxies the request' do
      response = HTTP.via('127.0.0.1', 8081, 'username', 'password').get test_endpoint
      expect(response.headers['X-Proxied']).to eq 'true'
    end

    it 'responds with the endpoint\'s body' do
      response = HTTP.via('127.0.0.1', 8081, 'username', 'password').get test_endpoint
      expect(response.to_s).to match(/<!doctype html>/)
    end
  end

  context 'with http proxy address, port, with wrong username and password' do
    it 'responds with 407' do
      response = HTTP.via('127.0.0.1', 8081, 'user', 'pass').get test_endpoint
      expect(response.status).to eq(407)
    end
  end

  context 'without proxy port' do
    it 'raises an argument error' do
      expect { HTTP.via('127.0.0.1') }.to raise_error HTTP::RequestError
    end
  end

  context 'posting forms to resources' do
    it 'is easy' do
      response = HTTP.post "#{test_endpoint}/form", :form => {:example => 'testing-form'}
      expect(response.to_s).to eq('passed :)')
    end
  end

  context 'posting with an explicit body' do
    it 'is easy' do
      response = HTTP.post "#{test_endpoint}/body", :body => 'testing-body'
      expect(response.to_s).to eq('passed :)')
    end
  end

  context 'with redirects' do
    it 'is easy for 301' do
      response = HTTP.with_follow(true).get("#{test_endpoint}/redirect-301")
      expect(response.to_s).to match(/<!doctype html>/)
    end

    it 'is easy for 302' do
      response = HTTP.with_follow(true).get("#{test_endpoint}/redirect-302")
      expect(response.to_s).to match(/<!doctype html>/)
    end

  end

  context 'head requests' do
    it 'is easy' do
      response = HTTP.head test_endpoint
      expect(response.status).to eq(200)
      expect(response['content-type']).to match(/html/)
    end
  end

  describe '.auth' do
    it 'sets Authorization header to the given value' do
      client = HTTP.auth 'abc'
      expect(client.default_headers[:authorization]).to eq 'abc'
    end

    it 'accepts any #to_s object' do
      client = HTTP.auth double :to_s => 'abc'
      expect(client.default_headers[:authorization]).to eq 'abc'
    end
  end

  describe '.basic_auth' do
    it 'fails when options is not a Hash' do
      expect { HTTP.basic_auth '[FOOBAR]' }.to raise_error
    end

    it 'fails when :pass is not given' do
      expect { HTTP.basic_auth :user => '[USER]' }.to raise_error
    end

    it 'fails when :user is not given' do
      expect { HTTP.basic_auth :pass => '[PASS]' }.to raise_error
    end

    it 'sets Authorization header with proper BasicAuth value' do
      client = HTTP.basic_auth :user => 'foo', :pass => 'bar'
      expect(client.default_headers[:authorization])
        .to match(/^Basic [A-Za-z0-9+\/]+=*$/)
    end
  end
end
