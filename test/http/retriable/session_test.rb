# frozen_string_literal: true

require "test_helper"

require "support/dummy_server"

describe HTTP::Retriable::Session do
  cover "HTTP::Retriable::Session*"
  run_server(:dummy) { DummyServer.new }

  let(:performer) { HTTP::Retriable::Performer.new({}) }
  let(:session) { HTTP::Retriable::Session.new(performer, HTTP::Options.new) }

  describe "#branch (private)" do
    it "returns a Retriable::Session when chaining" do
      chained = session.headers("Accept" => "text/html")

      assert_kind_of HTTP::Retriable::Session, chained
    end

    it "preserves performer through chaining" do
      chained = session.headers("Accept" => "text/html")
                       .timeout(10)

      assert_kind_of HTTP::Retriable::Session, chained
    end
  end

  describe "#make_client (private)" do
    it "creates a Retriable::Client for persistent connections" do
      p_client = session.persistent(dummy.endpoint)

      assert_kind_of HTTP::Retriable::Client, p_client
    ensure
      p_client&.close
    end
  end
end
