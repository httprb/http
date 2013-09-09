require 'spec_helper'

describe Http::Request do
  describe "headers" do
    subject { Http::Request.new(:get, "http://example.com/", :accept => "text/html") }

    it "sets explicit headers" do
      subject["Accept"].should eq("text/html")
    end

    it "sets implicit headers" do
      subject["Host"].should eq("example.com")
    end

    it "provides a #headers accessor" do
      subject.headers.should eq("Accept" => "text/html", "Host" => "example.com")
    end
  end
end
