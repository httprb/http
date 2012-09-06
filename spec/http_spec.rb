require 'spec_helper'
require 'json'

describe Http do
  let(:test_endpoint)  { "http://127.0.0.1:#{ExampleService::PORT}/" }
  let(:proxy_endpoint) { "#{test_endpoint}proxy" }

  context "getting resources" do
    it "should be easy" do
      response = Http.get test_endpoint
      response.should match(/<!doctype html>/)
    end

    it "should be easy to get a https resource" do
      response = Http.with_headers(:accept => 'application/json').get "https://api.github.com/users/samphippen"
      response["type"].should == "User"
    end

    it "can get some real world sites, following redirects if necessary" do
      sites = ["http://github.com/", "http://xkcd.com/", "http://www.spotify.com/"]
      sites.each do |site|
        resp = Http.with_response(:object).with_follow(true).get site
        resp.status.should == 200
      end
    end

    context "with_response" do
      it 'allows specifying :object' do
        res = Http.with_response(:object).get test_endpoint
        res.should be_a(Http::Response)
      end
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

    it "should not mess with the returned status" do
      client = Http.with_response(:object)
      res = client.get test_endpoint
      res.status.should == 200
      res = client.get "#{test_endpoint}not-found"
      res.status.should == 404
    end
  end

  context "with http proxy address and port" do
    it "should proxy the request" do
      response = Http.via("127.0.0.1", 8080).get proxy_endpoint
      response.should match(/Proxy!/)
    end
  end

  context "with http proxy address, port username and password" do
    it "should proxy the request" do
      response = Http.via("127.0.0.1", 8081, "username", "password").get proxy_endpoint
      response.should match(/Proxy!/)
    end
  end

  context "with http proxy address, port, with wrong username and password" do
    it "should proxy the request" do
      pending "fixing proxy support"

      response = Http.via("127.0.0.1", 8081, "user", "pass").get proxy_endpoint
      response.should match(/Proxy Authentication Required/)
    end
  end

  context "without proxy port" do
    it "should raise an argument error" do
      expect { Http.via("127.0.0.1") }.to raise_error ArgumentError
    end
  end

  context "posting to resources" do
    it "should be easy to post forms" do
      response = Http.post "#{test_endpoint}form", :form => {:example => 'testing-form'}
      response.should == "passed :)"
    end
  end

  context "posting with an explicit body" do
    it "should be easy to post" do
      response = Http.post "#{test_endpoint}body", :body => "testing-body"
      response.should == "passed :)"
    end
  end

  context "with redirects" do
    it "should be easy for 301" do
      response = Http.with_follow(true).get("#{test_endpoint}redirect-301")
      response.should match(/<!doctype html>/)
    end

    it "should be easy for 302" do
      response = Http.with_follow(true).get("#{test_endpoint}redirect-302")
      response.should match(/<!doctype html>/)
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
