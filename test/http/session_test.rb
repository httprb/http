# frozen_string_literal: true

require "test_helper"

require "support/dummy_server"

describe HTTP::Session do
  cover "HTTP::Session*"
  run_server(:dummy) { DummyServer.new }

  let(:session) { HTTP::Session.new }

  describe "#initialize" do
    it "creates a session with default options" do
      assert_kind_of HTTP::Options, session.default_options
    end

    it "creates a session with given options" do
      session = HTTP::Session.new(headers: { "Accept" => "text/html" })

      assert_equal "text/html", session.default_options.headers[:accept]
    end
  end

  describe "#request" do
    it "returns an HTTP::Response" do
      response = session.request(:get, dummy.endpoint)

      assert_kind_of HTTP::Response, response
    end

    it "creates a new client for each request" do
      client_ids = []
      original_new = HTTP::Client.method(:new)

      HTTP::Client.stub(:new, lambda { |*args|
        c = original_new.call(*args)
        client_ids << c.object_id
        c
      }) do
        session.get(dummy.endpoint)
        session.get(dummy.endpoint)
      end

      assert_equal 2, client_ids.uniq.size
    end
  end

  describe "Request::Builder" do
    it "builds an HTTP::Request from session options" do
      builder = HTTP::Request::Builder.new(session.default_options)
      req = builder.build(:get, "http://example.com/")

      assert_kind_of HTTP::Request, req
    end
  end

  describe "#persistent?" do
    it "returns false by default" do
      refute_predicate session, :persistent?
    end
  end

  describe "chaining" do
    it "returns a Session from headers" do
      chained = session.headers("Accept" => "text/html")

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from timeout" do
      chained = session.timeout(10)

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from cookies" do
      chained = session.cookies(session_id: "abc")

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from follow" do
      chained = session.follow

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from use" do
      chained = session.use(:auto_deflate)

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from nodelay" do
      chained = session.nodelay

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from encoding" do
      chained = session.encoding("UTF-8")

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from via" do
      chained = session.via("proxy.example.com", 8080)

      assert_kind_of HTTP::Session, chained
    end

    it "returns a Session from retriable" do
      chained = session.retriable

      assert_kind_of HTTP::Session, chained
    end

    it "preserves options through chaining" do
      chained = session.headers("Accept" => "text/html")
                       .timeout(10)
                       .cookies(session_id: "abc")

      assert_equal "text/html", chained.default_options.headers[:accept]
      assert_equal HTTP::Timeout::Global, chained.default_options.timeout_class
      assert_equal "session_id=abc", chained.default_options.headers["Cookie"]
    end
  end

  describe "thread safety" do
    it "can be shared across threads without errors" do
      shared_session = HTTP.headers("Accept" => "text/html").timeout(5)
      errors = []
      mutex = Mutex.new

      threads = Array.new(5) do
        Thread.new do
          shared_session.get(dummy.endpoint)
        rescue => e
          mutex.synchronize { errors << e }
        end
      end
      threads.each(&:join)

      assert_empty errors, "Expected no errors but got: #{errors.map(&:message).join(', ')}"
    end
  end

  describe "cookies during redirects" do
    it "forwards response cookies through redirect chain" do
      response = HTTP.follow.get("#{dummy.endpoint}/redirect-with-cookie")

      assert_includes response.to_s, "from_redirect=yes"
    end

    it "accumulates cookies across redirect hops" do
      response = HTTP.follow.get("#{dummy.endpoint}/redirect-cookie-chain/1")
      body = response.to_s

      assert_includes body, "first=1"
      assert_includes body, "second=2"
    end

    it "forwards initial request cookies through redirects" do
      response = HTTP.cookies(original: "value").follow.get("#{dummy.endpoint}/redirect-no-cookies")

      assert_includes response.to_s, "original=value"
    end

    it "deletes cookies with empty value during redirect" do
      response = HTTP.follow.get("#{dummy.endpoint}/redirect-set-then-delete/1")

      refute_includes response.to_s, "temp="
    end

    it "does not set Cookie header when no cookies present" do
      response = HTTP.follow.get("#{dummy.endpoint}/redirect-no-cookies")

      assert_equal "", response.to_s
    end

    it "applies features to redirect requests" do
      response = HTTP.use(:auto_deflate).follow.get("#{dummy.endpoint}/redirect-301")

      assert_equal "<!doctype html>", response.to_s
    end
  end

  describe "persistent" do
    it "returns an HTTP::Client" do
      p_client = HTTP::Session.new.persistent(dummy.endpoint)

      assert_kind_of HTTP::Client, p_client
    ensure
      p_client&.close
    end
  end

  describe "base_uri" do
    it "returns a Session from base_uri" do
      chained = session.base_uri(dummy.endpoint)

      assert_kind_of HTTP::Session, chained
    end

    it "preserves base_uri through chaining" do
      chained = session.base_uri("https://example.com/api")
                       .headers("Accept" => "application/json")

      assert_equal "https://example.com/api", chained.default_options.base_uri.to_s
      assert_equal "application/json", chained.default_options.headers[:accept]
    end

    it "resolves relative request paths against base_uri" do
      response = HTTP.base_uri(dummy.endpoint).get("/")

      assert_kind_of HTTP::Response, response
    end
  end
end
