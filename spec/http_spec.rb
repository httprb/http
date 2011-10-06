require 'spec_helper'

describe Http do
  context "getting resources" do
    it "should be easy" do
      # Fuck it, we'll do it live! (Testing against WEBRick or something coming soon)
      response = Http.get("http://www.google.com")
      response.should match(/<!doctype html>/)
    end
  end
end