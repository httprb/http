require 'spec_helper'
require 'json'

describe HTTP do
  let(:test_endpoint)  { "http://127.0.0.1:#{ExampleService::PORT}/" }

  context 'getting resources' do
    it 'should be easy' do
      response = HTTP.get test_endpoint
      expect(response.to_s).to match(/<!doctype html>/)
    end

    context 'with query string parameters' do
      it 'should be easy' do
        response = HTTP.get "#{test_endpoint}params" , :params => {:foo => 'bar'}
        expect(response.to_s).to match(/Params!/)
      end
    end

    context 'with headers' do
      it 'should be easy' do
        response = HTTP.accept(:json).get test_endpoint
        expect(response.to_s.include?('json')).to be true
      end
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
end
