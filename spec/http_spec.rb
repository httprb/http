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
  end

  context "posting to resources" do
    it "should be easy" do
      fragment = "<!doctype html><html><head><title>example</title></head></html>"
      response = Http.post "http://validator.w3.org/check", :form => {:fragment => fragment}

      response.should match(/HTML5/)
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
