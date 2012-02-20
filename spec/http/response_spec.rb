require 'spec_helper'

describe Http::Response do

  let(:subject){ Http::Response.new }

  describe "the response headers" do

    it 'are available through Hash-like methods' do
      subject["Content-Type"] = "text/plain"
      subject["Content-Type"].should eq("text/plain")
    end

    it 'are available through a `headers` accessor' do
      subject["Content-Type"] = "text/plain"
      subject.headers.should eq("Content-Type" => "text/plain")
    end

  end

  describe "parse_body" do

    it 'works on a registered mime-type' do
      subject["Content-Type"] = "application/json"
      subject.body = ::JSON.dump("hello" => "World")
      subject.parse_body.should eq("hello" => "World")
    end

    it 'returns the body on an unregistered mime-type' do
      subject["Content-Type"] = "text/plain"
      subject.body = "Hello world"
      subject.parse_body.should eq("Hello world")
    end

  end

  describe "to_a" do

    it 'mimics Rack' do
      subject.tap do |r|
        r.status  = 200
        r.headers = {"Content-Type" => "text/plain"}
        r.body    = "Hello world"
      end
      expected = [
        200,
        {"Content-Type" => "text/plain"},
        "Hello world"
      ]
      subject.to_a.should eq(expected)
    end

    it 'uses parse_body if known mime-type' do
      subject.tap do |r|
        r.status  = 200
        r.headers = {"Content-Type" => "application/json"}
        r.body    = ::JSON.dump("hello" => "World")
      end
      expected = [
        200,
        {"Content-Type" => "application/json"},
        {"hello" => "World"}
      ]
      subject.to_a.should eq(expected)
    end

  end

end
