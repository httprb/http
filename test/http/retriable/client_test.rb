# frozen_string_literal: true

require "test_helper"

describe HTTP::Retriable::Client do
  cover "HTTP::Retriable::Client*"
  describe "#branch (private)" do
    let(:performer) { HTTP::Retriable::Performer.new({}) }
    let(:client) { HTTP::Retriable::Client.new(performer, HTTP::Options.new) }

    it "returns a Retriable::Client when chaining" do
      chained = client.headers("Accept" => "text/html")

      assert_kind_of HTTP::Retriable::Client, chained
    end
  end
end
