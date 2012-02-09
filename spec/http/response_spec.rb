require 'spec_helper'

describe Http::Response do

  let(:subject){ Http::Response.new }

  describe "the response headers" do

    it 'are available through Hash-like methods' do
      subject["content-type"] = "text/plain"
      subject["content-type"].should eq("text/plain")
    end

    it 'are available through a `headers` accessor' do
      subject["content-type"] = "text/plain"
      subject.headers.should eq("content-type" => "text/plain")
    end

  end

  describe "parse_body" do

    it 'works on a registered mime-type' do
      subject["content-type"] = "application/json"
      subject.body = ::JSON.dump("hello" => "World")
      subject.parse_body.should eq("hello" => "World")
    end

    it 'returns the body on an unregistered mime-type' do
      subject["content-type"] = "text/plain"
      subject.body = "Hello world"
      subject.parse_body.should eq("Hello world")
    end

  end

end
