require 'spec_helper'

describe HTTP::RequestStream do
  describe "#initalize" do
    def construct(body)
      HTTP::RequestStream.new(nil, body, [], "")
    end

    it "doesn't throw on a nil body" do
      expect {construct []}.not_to raise_error
    end

    it "doesn't throw on a String body" do
      expect {construct "string body"}.not_to raise_error
    end

    it "doesn't throw on an Enumerable body" do
      expect {construct ["bees", "cows"]}.not_to raise_error
    end

    it "does throw on a body that isn't string, enumerable or nil" do
      expect {construct true}.to raise_error
    end
  end
end
