# frozen_string_literal: true

require "test_helper"

# A minimal stream that yields content then raises EOFError
class SimpleStream
  def initialize(content)
    @content = content
    @read = false
  end

  def readpartial(*)
    raise EOFError if @read

    @read = true
    @content
  end
end

describe HTTP::Features::Caching do
  cover "HTTP::Features::Caching*"

  let(:store)   { HTTP::Features::Caching::InMemoryStore.new }
  let(:feature) { HTTP::Features::Caching.new(store: store) }

  let(:request) do
    HTTP::Request.new(verb: :get, uri: "https://example.com/resource")
  end

  let(:post_request) do
    HTTP::Request.new(verb: :post, uri: "https://example.com/resource", body: "data")
  end

  let(:head_request) do
    HTTP::Request.new(verb: :head, uri: "https://example.com/resource")
  end

  def make_response(status: 200, headers: {}, body: "hello", req: request, version: "1.1",
                    proxy_headers: { "X-Proxy" => "true" })
    HTTP::Response.new(
      status:        status,
      version:       version,
      headers:       headers,
      proxy_headers: proxy_headers,
      body:          body,
      request:       req
    )
  end

  def make_streaming_response(status: 200, headers: {}, content: "hello", req: request, version: "1.1")
    HTTP::Response.new(
      status:     status,
      version:    version,
      headers:    headers,
      connection: SimpleStream.new(content),
      request:    req
    )
  end

  describe "#initialize" do
    it "uses InMemoryStore by default" do
      default_feature = HTTP::Features::Caching.new

      assert_instance_of HTTP::Features::Caching::InMemoryStore, default_feature.store
    end

    it "accepts a custom store" do
      assert_same store, feature.store
    end

    it "is a Feature subclass" do
      caching = HTTP::Features::Caching.new

      assert_kind_of HTTP::Feature, caching
    end
  end

  describe "#around_request" do
    it "yields the original request for non-GET/HEAD requests" do
      response = make_response(req: post_request)
      yielded_request = nil
      result = feature.around_request(post_request) do |req|
        yielded_request = req
        response
      end

      assert_same response, result
      assert_same post_request, yielded_request
    end

    it "does not consult the store for non-cacheable methods" do
      # Even if the store somehow has an entry for a POST, it should not be used
      entry = HTTP::Features::Caching::Entry.new(
        status:        200,
        version:       "1.1",
        headers:       HTTP::Headers.coerce("Cache-Control" => "max-age=3600"),
        proxy_headers: HTTP::Headers.coerce({}),
        body:          "cached",
        request_uri:   post_request.uri,
        stored_at:     Time.now
      )
      store.store(post_request, entry)

      response = make_response(req: post_request, body: "fresh")
      result = feature.around_request(post_request) { response }

      assert_same response, result
    end

    it "yields the original request when no cache entry exists" do
      response = make_response
      yielded_request = nil
      result = feature.around_request(request) do |req|
        yielded_request = req
        response
      end

      assert_same response, result
      assert_same request, yielded_request
    end

    context "with a fresh cached entry" do
      it "returns cached response without yielding" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("Cache-Control" => "max-age=3600"),
          proxy_headers: HTTP::Headers.coerce("X-Proxy" => "cached"),
          body:          "cached body",
          request_uri:   request.uri,
          stored_at:     Time.now
        )
        store.store(request, entry)

        yielded = false
        result = feature.around_request(request) { yielded = true }

        refute yielded
        assert_equal 200, result.status.code
        assert_equal "cached body", result.body.to_s
        assert_equal request.uri, result.request.uri
        assert_equal "1.1", result.version
        assert_equal "max-age=3600", result.headers["Cache-Control"]
      end

      it "preserves proxy_headers in cached response" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("Cache-Control" => "max-age=3600"),
          proxy_headers: HTTP::Headers.coerce("X-Proxy" => "cached-proxy"),
          body:          "cached body",
          request_uri:   request.uri,
          stored_at:     Time.now
        )
        store.store(request, entry)

        result = feature.around_request(request) { raise "should not yield" }

        assert_equal "cached-proxy", result.proxy_headers["X-Proxy"]
      end
    end

    context "with a stale cached entry" do
      it "adds If-None-Match header when entry has ETag" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("ETag" => '"abc123"', "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "old body",
          request_uri:   request.uri,
          stored_at:     Time.now - 100
        )
        store.store(request, entry)

        sent_request = nil
        response = make_response(status: 200, body: "new body")
        feature.around_request(request) do |req|
          sent_request = req
          response
        end

        assert_equal '"abc123"', sent_request.headers["If-None-Match"]
        # Verify the original request headers are not mutated (dup was called)
        assert_nil request.headers["If-None-Match"]
      end

      it "does not add If-None-Match when entry has no ETag" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("Last-Modified" => "Wed, 01 Jan 2025 00:00:00 GMT",
                                              "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "old body",
          request_uri:   request.uri,
          stored_at:     Time.now - 100
        )
        store.store(request, entry)

        sent_request = nil
        response = make_response(status: 200, body: "new body")
        feature.around_request(request) do |req|
          sent_request = req
          response
        end

        assert_nil sent_request.headers["If-None-Match"]
      end

      it "adds If-Modified-Since header when entry has Last-Modified" do
        last_mod = "Wed, 01 Jan 2025 00:00:00 GMT"
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("Last-Modified" => last_mod, "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "old body",
          request_uri:   request.uri,
          stored_at:     Time.now - 100
        )
        store.store(request, entry)

        sent_request = nil
        response = make_response(status: 200, body: "new body")
        feature.around_request(request) do |req|
          sent_request = req
          response
        end

        assert_equal last_mod, sent_request.headers["If-Modified-Since"]
      end

      it "does not add If-Modified-Since when entry has no Last-Modified" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("ETag" => '"abc"', "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "old body",
          request_uri:   request.uri,
          stored_at:     Time.now - 100
        )
        store.store(request, entry)

        sent_request = nil
        response = make_response(status: 200, body: "new body")
        feature.around_request(request) do |req|
          sent_request = req
          response
        end

        assert_nil sent_request.headers["If-Modified-Since"]
      end

      it "preserves request verb, uri, version, body, and proxy in revalidation request" do
        req_with_proxy = HTTP::Request.new(
          verb:    :get,
          uri:     "https://example.com/resource",
          body:    "request body",
          version: "1.0",
          proxy:   { proxy_host: "proxy.example.com", proxy_port: 8080 }
        )
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("ETag" => '"abc"', "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "old body",
          request_uri:   req_with_proxy.uri,
          stored_at:     Time.now - 100
        )
        store.store(req_with_proxy, entry)

        sent_request = nil
        response = make_response(status: 200, body: "new body", req: req_with_proxy)
        feature.around_request(req_with_proxy) do |req|
          sent_request = req
          response
        end

        assert_equal :get, sent_request.verb
        assert_equal req_with_proxy.uri, sent_request.uri
        assert_equal "1.0", sent_request.version
        assert_equal "request body", sent_request.body.source
        assert_equal({ proxy_host: "proxy.example.com", proxy_port: 8080 }, sent_request.proxy)
      end

      it "returns cached response on 304 and updates stored_at" do
        old_stored_at = Time.now - 100
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("ETag" => '"abc"', "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "cached body",
          request_uri:   request.uri,
          stored_at:     old_stored_at
        )
        store.store(request, entry)

        not_modified = make_response(status: 304, body: "")
        result = feature.around_request(request) { not_modified }

        assert_equal 200, result.status.code
        assert_equal "cached body", result.body.to_s
        assert_same request, result.request
        # Verify revalidate! was called (stored_at updated)
        assert_operator entry.stored_at, :>, old_stored_at
      end

      it "merges 304 response headers into cached entry" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("ETag" => '"abc"', "Cache-Control" => "max-age=0",
                                              "X-Old" => "preserved"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "cached body",
          request_uri:   request.uri,
          stored_at:     Time.now - 100
        )
        store.store(request, entry)

        not_modified = make_response(
          status:  304,
          headers: { "ETag" => '"def"', "X-New" => "added" },
          body:    ""
        )
        result = feature.around_request(request) { not_modified }

        assert_equal '"def"', result.headers["ETag"]
        assert_equal "added", result.headers["X-New"]
        assert_equal "preserved", result.headers["X-Old"]
      end

      it "returns new response on non-304" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("ETag" => '"abc"', "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "old body",
          request_uri:   request.uri,
          stored_at:     Time.now - 100
        )
        store.store(request, entry)

        new_response = make_response(status: 200, body: "new body")
        result = feature.around_request(request) { new_response }

        assert_same new_response, result
      end

      it "uses status predicate to detect 304 Not Modified" do
        entry = HTTP::Features::Caching::Entry.new(
          status:        200,
          version:       "1.1",
          headers:       HTTP::Headers.coerce("ETag" => '"abc"', "Cache-Control" => "max-age=0"),
          proxy_headers: HTTP::Headers.coerce({}),
          body:          "cached body",
          request_uri:   request.uri,
          stored_at:     Time.now - 100
        )
        store.store(request, entry)

        # A non-304 response should be returned as-is
        ok_response = make_response(status: 200, body: "new body")
        result = feature.around_request(request) { ok_response }

        assert_same ok_response, result
      end
    end

    it "caches HEAD requests" do
      entry = HTTP::Features::Caching::Entry.new(
        status:        200,
        version:       "1.1",
        headers:       HTTP::Headers.coerce("Cache-Control" => "max-age=3600"),
        proxy_headers: HTTP::Headers.coerce({}),
        body:          "",
        request_uri:   head_request.uri,
        stored_at:     Time.now
      )
      store.store(head_request, entry)

      yielded = false
      result = feature.around_request(head_request) { yielded = true }

      refute yielded
      assert_equal 200, result.status.code
    end
  end

  describe "#wrap_response" do
    it "stores cacheable responses and returns response with correct properties" do
      response = make_response(headers: { "Cache-Control" => "max-age=3600" })
      result = feature.wrap_response(response)

      assert store.lookup(request)
      assert_equal 200, result.status.code
      assert_equal "1.1", result.version
      assert_equal "hello", result.body.to_s
      assert_same request, result.request
    end

    it "preserves headers in stored response" do
      response = make_response(headers: { "Cache-Control" => "max-age=3600", "X-Custom" => "value" })
      result = feature.wrap_response(response)

      assert_equal "value", result.headers["X-Custom"]
    end

    it "preserves proxy_headers in stored response" do
      response = make_response(
        headers:       { "Cache-Control" => "max-age=3600" },
        proxy_headers: { "X-Proxy" => "test-value" }
      )
      result = feature.wrap_response(response)

      assert_equal "test-value", result.proxy_headers["X-Proxy"]
    end

    it "does not store responses with no-store" do
      response = make_response(headers: { "Cache-Control" => "no-store" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "does not store non-cacheable status codes (500)" do
      response = make_response(status: 500, headers: { "Cache-Control" => "max-age=60" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "does not store 400 responses" do
      response = make_response(status: 400, headers: { "Cache-Control" => "max-age=60" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "stores 399 responses" do
      response = make_response(status: 399, headers: { "Cache-Control" => "max-age=60" })
      feature.wrap_response(response)

      assert store.lookup(request)
    end

    it "does not store 1xx responses" do
      response = make_response(status: 100, headers: { "Cache-Control" => "max-age=60" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "does not store 199 responses" do
      response = make_response(status: 199, headers: { "Cache-Control" => "max-age=60" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "stores 200 responses" do
      response = make_response(status: 200, headers: { "Cache-Control" => "max-age=60" })
      feature.wrap_response(response)

      assert store.lookup(request)
    end

    it "does not store POST responses" do
      response = make_response(
        headers: { "Cache-Control" => "max-age=3600" },
        req:     post_request
      )
      result = feature.wrap_response(response)

      assert_same response, result
      assert_nil store.lookup(post_request)
    end

    it "returns original response for non-cacheable responses" do
      response = make_response(headers: { "Cache-Control" => "no-store" })
      result = feature.wrap_response(response)

      assert_same response, result
    end

    it "stores response with ETag" do
      response = make_response(headers: { "ETag" => '"v1"' })
      feature.wrap_response(response)

      assert store.lookup(request)
    end

    it "stores response with Last-Modified" do
      response = make_response(headers: { "Last-Modified" => "Wed, 01 Jan 2025 00:00:00 GMT" })
      feature.wrap_response(response)

      assert store.lookup(request)
    end

    it "stores response with Expires" do
      response = make_response(headers: { "Expires" => "Thu, 01 Jan 2099 00:00:00 GMT" })
      feature.wrap_response(response)

      assert store.lookup(request)
    end

    it "does not store response without freshness info" do
      response = make_response(headers: {})
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "does not treat non-max-age directives as freshness info" do
      response = make_response(headers: { "Cache-Control" => "public" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "preserves uri in stored response" do
      response = make_response(headers: { "Cache-Control" => "max-age=3600" })
      result = feature.wrap_response(response)

      assert_equal request.uri, result.uri
    end

    it "returns a response with string body" do
      response = make_response(headers: { "Cache-Control" => "max-age=3600" }, body: "hello")
      result = feature.wrap_response(response)

      assert_equal "hello", result.body.to_s
    end

    it "eagerly reads streaming body into a string" do
      response = make_streaming_response(
        headers: { "Cache-Control" => "max-age=3600" },
        content: "streamed content"
      )
      result = feature.wrap_response(response)

      assert_instance_of String, result.body
      assert_equal "streamed content", result.body
    end

    it "stores 301 redirect responses" do
      response = make_response(
        status:  301,
        headers: { "Cache-Control" => "max-age=3600", "Location" => "https://example.com/new" }
      )
      feature.wrap_response(response)

      assert store.lookup(request)
    end

    it "stores entry with correct status, version, headers, body, and request_uri" do
      response = make_response(
        status:  200,
        headers: { "Cache-Control" => "max-age=3600", "X-Custom" => "val" },
        body:    "stored body",
        version: "1.0"
      )
      feature.wrap_response(response)

      entry = store.lookup(request)

      assert_equal 200, entry.status
      assert_equal "1.0", entry.version
      assert_equal "val", entry.headers["X-Custom"]
      assert_equal "stored body", entry.body
      assert_equal request.uri, entry.request_uri
      assert_instance_of Time, entry.stored_at
    end

    it "does not store no-store responses even when freshness info is present" do
      response = make_response(headers: { "Cache-Control" => "no-store, max-age=3600" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "does not store no-store responses with ETag" do
      response = make_response(headers: { "Cache-Control" => "no-store", "ETag" => '"v1"' })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "handles uppercase NO-STORE with freshness info" do
      response = make_response(headers: { "Cache-Control" => "NO-STORE", "ETag" => '"v1"' })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "handles Cache-Control with spaces around commas and freshness info" do
      response = make_response(headers: { "Cache-Control" => "max-age=3600 , no-store" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "handles no-store with trailing whitespace before comma" do
      response = make_response(headers: { "Cache-Control" => "no-store , max-age=3600" })
      feature.wrap_response(response)

      assert_nil store.lookup(request)
    end

    it "dups headers in stored entry to prevent mutation" do
      response = make_response(headers: { "Cache-Control" => "max-age=3600", "X-Custom" => "original" })
      feature.wrap_response(response)

      entry = store.lookup(request)
      entry.headers["X-Custom"] = "mutated"

      assert_equal "original", response.headers["X-Custom"]
    end

    it "stores proxy_headers in entry" do
      response = make_response(
        headers:       { "Cache-Control" => "max-age=3600" },
        proxy_headers: { "X-Proxy" => "stored-proxy" }
      )
      feature.wrap_response(response)

      entry = store.lookup(request)

      assert_equal "stored-proxy", entry.proxy_headers["X-Proxy"]
    end

    it "stores entry with integer status code" do
      response = make_response(status: 200, headers: { "Cache-Control" => "max-age=3600" })
      feature.wrap_response(response)

      entry = store.lookup(request)

      assert_instance_of Integer, entry.status
    end
  end

  describe "feature registration" do
    it "is registered as :caching" do
      assert_equal HTTP::Features::Caching, HTTP::Options.available_features[:caching]
    end
  end
end

describe HTTP::Features::Caching::Entry do
  cover "HTTP::Features::Caching::Entry*"

  def make_entry(headers: {}, stored_at: Time.now)
    HTTP::Features::Caching::Entry.new(
      status:        200,
      version:       "1.1",
      headers:       HTTP::Headers.coerce(headers),
      proxy_headers: HTTP::Headers.coerce({}),
      body:          "body",
      request_uri:   HTTP::URI.parse("https://example.com/"),
      stored_at:     stored_at
    )
  end

  describe "#fresh?" do
    it "is fresh when max-age has not elapsed" do
      entry = make_entry(headers: { "Cache-Control" => "max-age=3600" })

      assert_predicate entry, :fresh?
    end

    it "is not fresh when max-age has elapsed" do
      entry = make_entry(
        headers:   { "Cache-Control" => "max-age=60" },
        stored_at: Time.now - 120
      )

      refute_predicate entry, :fresh?
    end

    it "is fresh when Expires is in the future" do
      entry = make_entry(headers: { "Expires" => (Time.now + 3600).httpdate })

      assert_predicate entry, :fresh?
    end

    it "is not fresh when Expires is in the past" do
      entry = make_entry(headers: { "Expires" => (Time.now - 3600).httpdate })

      refute_predicate entry, :fresh?
    end

    it "is not fresh when no-cache is present" do
      entry = make_entry(headers: { "Cache-Control" => "max-age=3600, no-cache" })

      refute_predicate entry, :fresh?
    end

    it "is not fresh when no-cache is present in uppercase" do
      entry = make_entry(headers: { "Cache-Control" => "max-age=3600, NO-CACHE" })

      refute_predicate entry, :fresh?
    end

    it "is not fresh without any freshness info" do
      entry = make_entry(headers: {})

      refute_predicate entry, :fresh?
    end

    it "accounts for Age header in freshness" do
      entry = make_entry(headers: { "Cache-Control" => "max-age=100", "Age" => "90" })

      assert_predicate entry, :fresh?
    end

    it "is not fresh when Age exceeds max-age" do
      entry = make_entry(headers: { "Cache-Control" => "max-age=100", "Age" => "200" })

      refute_predicate entry, :fresh?
    end

    it "treats Age as float for precision" do
      # Age=99 with max-age=100: fresh because 99.0 + ~0 < 100
      entry = make_entry(headers: { "Cache-Control" => "max-age=100", "Age" => "99" })

      assert_predicate entry, :fresh?
    end

    it "defaults base_age to 0.0 when no Age header" do
      # Without Age header, base_age should be 0.0, not 1.0
      # A freshly stored entry with max-age=1 should be fresh
      entry = make_entry(headers: { "Cache-Control" => "max-age=1" })

      assert_predicate entry, :fresh?
    end

    it "handles non-numeric Age header gracefully" do
      entry = make_entry(headers: { "Cache-Control" => "max-age=3600", "Age" => "abc" })

      assert_predicate entry, :fresh?
    end

    it "treats non-numeric Age as zero for freshness calculation" do
      entry = make_entry(
        headers:   { "Cache-Control" => "max-age=100", "Age" => "abc" },
        stored_at: Time.now - 100.5
      )

      refute_predicate entry, :fresh?
    end

    it "handles invalid Expires gracefully" do
      entry = make_entry(headers: { "Expires" => "not-a-date" })

      refute_predicate entry, :fresh?
    end

    it "falls through to Expires when Cache-Control has no max-age" do
      entry = make_entry(headers: {
        "Cache-Control" => "public",
        "Expires"       => (Time.now + 3600).httpdate
      })

      assert_predicate entry, :fresh?
    end

    it "prefers max-age over Expires when both present" do
      # max-age=0 makes it stale even though Expires is in the future
      entry = make_entry(
        headers:   { "Cache-Control" => "max-age=0", "Expires" => (Time.now + 3600).httpdate },
        stored_at: Time.now - 1
      )

      refute_predicate entry, :fresh?
    end
  end

  describe "#update_headers!" do
    it "merges new headers into the entry" do
      entry = make_entry(headers: { "ETag" => '"old"', "X-Keep" => "kept" })
      new_headers = HTTP::Headers.coerce("ETag" => '"new"', "X-Added" => "added")

      entry.update_headers!(new_headers)

      assert_equal '"new"', entry.headers["ETag"]
      assert_equal "added", entry.headers["X-Added"]
      assert_equal "kept", entry.headers["X-Keep"]
    end

    it "overwrites existing headers with 304 values" do
      entry = make_entry(headers: { "Cache-Control" => "max-age=60" })
      new_headers = HTTP::Headers.coerce("Cache-Control" => "max-age=120")

      entry.update_headers!(new_headers)

      assert_equal "max-age=120", entry.headers["Cache-Control"]
    end
  end

  describe "#revalidate!" do
    it "resets stored_at to current time" do
      old_time = Time.now - 1000
      entry = make_entry(stored_at: old_time)
      entry.revalidate!

      assert_operator entry.stored_at, :>, old_time
    end
  end

  describe "attribute readers" do
    it "exposes status" do
      entry = make_entry

      assert_equal 200, entry.status
    end

    it "exposes version" do
      entry = make_entry

      assert_equal "1.1", entry.version
    end

    it "exposes body" do
      entry = make_entry

      assert_equal "body", entry.body
    end

    it "exposes request_uri" do
      entry = make_entry

      assert_equal HTTP::URI.parse("https://example.com/"), entry.request_uri
    end

    it "exposes proxy_headers" do
      entry = make_entry

      assert_instance_of HTTP::Headers, entry.proxy_headers
    end
  end
end

describe HTTP::Features::Caching::InMemoryStore do
  cover "HTTP::Features::Caching::InMemoryStore*"

  let(:store) { HTTP::Features::Caching::InMemoryStore.new }

  let(:request) do
    HTTP::Request.new(verb: :get, uri: "https://example.com/resource")
  end

  let(:entry) do
    HTTP::Features::Caching::Entry.new(
      status:        200,
      version:       "1.1",
      headers:       HTTP::Headers.coerce({}),
      proxy_headers: HTTP::Headers.coerce({}),
      body:          "test",
      request_uri:   request.uri,
      stored_at:     Time.now
    )
  end

  describe "#lookup" do
    it "returns nil for unknown requests" do
      assert_nil store.lookup(request)
    end

    it "returns stored entry" do
      store.store(request, entry)

      assert_same entry, store.lookup(request)
    end
  end

  describe "#store" do
    it "stores and retrieves by request method and URI" do
      store.store(request, entry)

      assert_same entry, store.lookup(request)
    end

    it "stores different entries for different URIs" do
      other_request = HTTP::Request.new(verb: :get, uri: "https://example.com/other")
      other_entry = HTTP::Features::Caching::Entry.new(
        status:        200,
        version:       "1.1",
        headers:       HTTP::Headers.coerce({}),
        proxy_headers: HTTP::Headers.coerce({}),
        body:          "other",
        request_uri:   other_request.uri,
        stored_at:     Time.now
      )

      store.store(request, entry)
      store.store(other_request, other_entry)

      assert_same entry, store.lookup(request)
      assert_same other_entry, store.lookup(other_request)
    end

    it "stores different entries for different verbs" do
      head_request = HTTP::Request.new(verb: :head, uri: "https://example.com/resource")
      head_entry = HTTP::Features::Caching::Entry.new(
        status:        200,
        version:       "1.1",
        headers:       HTTP::Headers.coerce({}),
        proxy_headers: HTTP::Headers.coerce({}),
        body:          "",
        request_uri:   head_request.uri,
        stored_at:     Time.now
      )

      store.store(request, entry)
      store.store(head_request, head_entry)

      assert_same entry, store.lookup(request)
      assert_same head_entry, store.lookup(head_request)
    end

    it "replaces existing entry" do
      new_entry = HTTP::Features::Caching::Entry.new(
        status:        200,
        version:       "1.1",
        headers:       HTTP::Headers.coerce({}),
        proxy_headers: HTTP::Headers.coerce({}),
        body:          "updated",
        request_uri:   request.uri,
        stored_at:     Time.now
      )

      store.store(request, entry)
      store.store(request, new_entry)

      assert_same new_entry, store.lookup(request)
    end

    it "finds entry using a different request object with the same verb and uri" do
      store.store(request, entry)
      same_request = HTTP::Request.new(verb: :get, uri: "https://example.com/resource")

      assert_same entry, store.lookup(same_request)
    end
  end
end
