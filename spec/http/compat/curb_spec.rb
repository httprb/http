require 'spec_helper'

require 'http/compat/curb'

describe Curl do
  let(:test_endpoint)  { "http://127.0.0.1:#{ExampleService::PORT}/" }

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
      requests  = [test_endpoint]
      responses = []

      multi = Curl::Multi.new

      requests.each do |url|
        response = Curl::Easy.new url, :get
        multi.add response
        responses << response
      end

      multi.perform
      responses.first.body_str.should match(/<!doctype html>/)
    end
  end
end
