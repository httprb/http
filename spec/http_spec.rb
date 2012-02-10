require 'spec_helper'
require 'json'

describe Http do
  let(:test_endpoint) { "http://127.0.0.1:#{TEST_SERVER_PORT}/" }

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
end
