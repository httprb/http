require 'spec_helper'

require 'http/compat/curb'

describe Curl do
  let(:test_endpoint)  { "http://127.0.0.1:#{TEST_SERVER_PORT}/" }

  describe Curl::Easy do
    it "gets resources" do
      response = Curl::Easy.http_get test_endpoint
      response.body_str.should match(/<!doctype html>/)
    end

    context :errors do
      it "raises Curl::Err::HostResolutionError if asked to connect to a nonexistent domain" do
        expect {
          Curl::Easy.http_get "http://totallynonexistentdomain.com"
        }.to raise_exception(Curl::Err::HostResolutionError)
      end
    end
  end
  
  describe Curl::Multi do
    it "gets resources" do
      called = false
      
      Curl::Multi.get(test_endpoint) do |response|
        called = true
        response.should be_a Curl::Easy
        response.body_str.should match(/<!doctype html>/)
      end
      
      called.should be_true
    end
  end
end