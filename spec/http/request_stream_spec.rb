require 'spec_helper'

describe Http::RequestStream do
  describe "#initalize" do
    def construct(body)
      Http::RequestStream.new(nil, body, [], "")
    end

    it "doesn't throw on a nil body" do
      expect {construct []}.to_not raise_error(ArgumentError)
    end

    it "doesn't throw on a String body" do
      expect {construct "string body"}.to_not raise_error(ArgumentError)
    end

    it "doesn't throw on an Enumerable body" do
      expect {construct ["bees", "cows"]}.to_not raise_error(ArgumentError)
    end

    it "does throw on a body that isn't string, enumerable or nil" do
      expect {construct true}.to raise_error(ArgumentError)

    end
  end
end
