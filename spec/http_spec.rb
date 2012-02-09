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
      it "should be easy" do
        request = nil
        response = nil

        Http.on(:request)  {|r| request = r}
            .on(:response)  {|r| response = r}
            .get test_endpoint

        request.should_not be_nil
        response.should_not be_nil
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
