require 'spec_helper'
require 'http/compat/curb'

describe Curl::Easy do
  it "gets resources" do
    # Fuck it, we'll do it live! (Testing against WEBRick or something coming soon)
    response = Curl::Easy.http_get "http://www.google.com"
    response.body_str.should match(/<!doctype html>/)
  end
end
