require 'spec_helper'
require 'json'

describe Http do
  context "getting resources" do
    it "should be easy" do
      # Fuck it, we'll do it live! (Testing against WEBRick or something coming soon)
      response = Http.get "http://www.google.com"
      response.should match(/<!doctype html>/)
    end

    context "with headers" do
      it "should be easy" do
        response = Http.accept(:json).get("https://github.com/tarcieri/http/commit/HEAD")

        # Congratulations first committer, your prize is to break the build!
        response['commit']['author']['name'].should == "Tony Arcieri"
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
end
