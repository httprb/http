require 'spec_helper'
require 'json'

describe Http do
  let(:test_endpoint) { "http://127.0.0.1:#{ExampleService::PORT}/" }

  context "getting resources" do
    it "should be easy" do
      response = Http.get test_endpoint
      response.should match(/<!doctype html>/)
    end

    context "with headers" do
      it "should be easy" do
        response = Http.accept(:json).get test_endpoint
        response['json'].should be_true
      end
    end

    context "with callbacks" do
      it "fires a request callback" do
        pending 'Http::Request is not yet implemented'

        request = nil
        Http.on(:request) {|r| request = r}.get test_endpoint
        request.should be_a Http::Request
      end

      it "fires a response callback" do
        response = nil
        Http.on(:response) {|r| response = r}.get test_endpoint
        response.should be_a Http::Response
      end
    end    
  end
  
  context "with http proxy address and port" do
    it "should proxy the request" do
      response = Http.via("127.0.0.1", 65432).get test_endpoint
      response.should match(/<!doctype html>/)
    end
  end
  
  context "with http proxy address, port username and password" do
    it "should proxy the request" do
      response = Http.via("127.0.0.1", 65432, "username", "password").get test_endpoint
      response.should match(/<!doctype html>/)
    end
  end
  
  context "without proxy port" do
    it "should raise an argument error" do
      expect { Http.via("127.0.0.1") }.to raise_error ArgumentError
    end
  end

  context "posting to resources" do
    it "should be easy" do
      response = Http.post test_endpoint, :form => {:example => 'testing'}
      response.should == "passed :)"
    end
  end

  context "head requests" do
    it "should be easy" do
      response = Http.head test_endpoint
      response.status.should == 200
      response['content-type'].should match(/html/)
    end
  end

  it "should be chainable" do
    response = Http.accept(:json).on(:response){|r| seen = r}.get(test_endpoint)
    response['json'].should be_true
  end

end
