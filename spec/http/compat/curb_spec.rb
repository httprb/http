require 'spec_helper'

require 'http/compat/curb'

describe Curl::Easy do
  let(:test_endpoint) { "http://127.0.0.1:#{TEST_SERVER_PORT}/" }
    
  it "gets resources" do
    response = Curl::Easy.http_get test_endpoint
    response.body_str.should match(/<!doctype html>/)
  end

  context :errors do
    it "raises Curl::Err::HostResolutionError if asked to connect to a nonexistent domainwh" do
      expect {
        Curl::Easy.http_get "http://totallynonexistentdomain.com"
      }.to raise_exception(Curl::Err::HostResolutionError)
    end
  end
end