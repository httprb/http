require 'spec_helper'
require 'json'

describe HTTP do
  let(:test_endpoint)  { "http://127.0.0.1:#{ExampleService::PORT}/" }

  context 'getting resources' do
    it 'should be easy' do
      response = HTTP.get test_endpoint
      expect(response.to_s).to match(/<!doctype html>/)
    end

    context 'with URI instance' do
      it 'should be easy' do
        response = HTTP.get URI(test_endpoint)
        expect(response.to_s).to match(/<!doctype html>/)
      end
    end

    context 'with query string parameters' do
      it 'should be easy' do
        response = HTTP.get "#{test_endpoint}params" , :params => {:foo => 'bar'}
        expect(response.to_s).to match(/Params!/)
      end
    end

    context 'with query string parameters in the URI and opts hash' do
      it 'includes both' do
        response = HTTP.get "#{test_endpoint}multiple-params?foo=bar" , :params => {:baz => 'quux'}
        expect(response.to_s).to match(/More Params!/)
      end
    end

    context 'with headers' do
      it 'should be easy' do
        response = HTTP.accept('application/json').get test_endpoint
        expect(response.to_s.include?('json')).to be true
      end
    end
  end

  context 'with http proxy address and port' do
    it 'should proxy the request' do
      response = HTTP.via('127.0.0.1', 8080).get test_endpoint
      expect(response.headers['X-Proxied']).to eq 'true'
    end
  end

  context 'with http proxy address, port username and password' do
    it 'should proxy the request' do
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
    it 'should raise an argument error' do
      expect { HTTP.via('127.0.0.1') }.to raise_error HTTP::RequestError
    end
  end

  context 'posting to resources' do
    it 'should be easy to post forms' do
      response = HTTP.post "#{test_endpoint}form", :form => {:example => 'testing-form'}
      expect(response.to_s).to eq('passed :)')
    end
  end

  context 'posting with an explicit body' do
    it 'should be easy to post' do
      response = HTTP.post "#{test_endpoint}body", :body => 'testing-body'
      expect(response.to_s).to eq('passed :)')
    end
  end

  context 'with redirects' do
    it 'should be easy for 301' do
      response = HTTP.with_follow(true).get("#{test_endpoint}redirect-301")
      expect(response.to_s).to match(/<!doctype html>/)
    end

    it 'should be easy for 302' do
      response = HTTP.with_follow(true).get("#{test_endpoint}redirect-302")
      expect(response.to_s).to match(/<!doctype html>/)
    end

  end

  context 'head requests' do
    it 'should be easy' do
      response = HTTP.head test_endpoint
      expect(response.status).to eq(200)
      expect(response['content-type']).to match(/html/)
    end
  end

  describe '.auth' do
    context 'with no arguments' do
      specify { expect { HTTP.auth }.to raise_error }
    end

    context 'with one argument' do
      it 'returns branch with Authorization header as is' do
        expect(HTTP).to receive(:with) \
          .with :authorization => 'foobar'

        HTTP.auth :foobar
      end
    end

    context 'with two arguments' do
      it 'builds value with AuthorizationHeader builder' do
        expect(HTTP::AuthorizationHeader).to receive(:build) \
          .with(:bearer, :token => 'token')

        HTTP.auth :bearer, :token => 'token'
      end
    end

    context 'with more than two arguments' do
      specify { expect { HTTP.auth 1, 2, 3 }.to raise_error }
    end
  end
end
