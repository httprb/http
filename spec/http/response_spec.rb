require 'spec_helper'

describe Http::Response do
  describe "headers" do
    subject { Http::Response.new(200, "1.1", "Content-Type" => "text/plain") }

    it "exposes header fields for easy access" do
      subject["Content-Type"].should eq("text/plain")
    end

    it "provides a #headers accessor too" do
      subject.headers.should eq("Content-Type" => "text/plain")
    end
  end

  describe "#parse_body" do
    context "on a registered MIME type" do
      let(:body) { ::JSON.dump("Hello" => "World") }
      subject { Http::Response.new(200, "1.1", {"Content-Type" => "application/json"}, body) }

      it "returns a parsed response body" do
        subject.parse_body.should eq ::JSON.parse(body)
      end
    end

    context "on an unregistered MIME type" do
      let(:body) { "Hello world" }
      subject { Http::Response.new(200, "1.1", {"Content-Type" => "text/plain"}, body) }

      it "returns the raw body as a String" do
        subject.parse_body.should eq(body)
      end
    end
  end

  describe "to_a" do
    context "on a registered MIME type" do
      let(:body) { ::JSON.dump("Hello" => "World") }
      let(:content_type) { "application/json" }
      subject { Http::Response.new(200, "1.1", {"Content-Type" => content_type}, body) }

      it "retuns a Rack-like array with a parsed response body" do
        subject.to_a.should eq([200, {"Content-Type" => content_type}, ::JSON.parse(body)])
      end
    end

    context "on an unregistered MIME type" do
      let(:body)         { "Hello world" }
      let(:content_type) { "text/plain" }
      subject { Http::Response.new(200, "1.1", {"Content-Type" => content_type}, body) }

      it "returns a Rack-like array" do
        subject.to_a.should eq([200, {"Content-Type" => content_type}, body])
      end
    end
  end
end
