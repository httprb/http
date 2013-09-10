require 'spec_helper'

describe HTTP::Request do
  describe "headers" do
    subject { HTTP::Request.new(:get, "http://example.com/", :accept => "text/html") }

    it "sets explicit headers" do
      expect(subject["Accept"]).to eq("text/html")
    end

    it "sets implicit headers" do
      expect(subject["Host"]).to eq("example.com")
    end

    it "provides a #headers accessor" do
      expect(subject.headers).to eq("Accept" => "text/html", "Host" => "example.com")
    end
  end
end
