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

class HTTPFeaturesCachingTest < Minitest::Test
  cover "HTTP::Features::Caching*"

  def store
    @store ||= HTTP::Features::Caching::InMemoryStore.new
  end

  def feature
    @feature ||= HTTP::Features::Caching.new(store: store)
  end

  def request
    @request ||= HTTP::Request.new(verb: :get, uri: "https://example.com/resource")
  end

  def post_request
    @post_request ||= HTTP::Request.new(verb: :post, uri: "https://example.com/resource", body: "data")
  end

  def head_request
    @head_request ||= HTTP::Request.new(verb: :head, uri: "https://example.com/resource")
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

  # -- #initialize --

  def test_initialize_uses_in_memory_store_by_default
    default_feature = HTTP::Features::Caching.new

    assert_instance_of HTTP::Features::Caching::InMemoryStore, default_feature.store
  end

  def test_initialize_accepts_a_custom_store
    assert_same store, feature.store
  end

  def test_initialize_is_a_feature_subclass
    caching = HTTP::Features::Caching.new

    assert_kind_of HTTP::Feature, caching
  end

  # -- #around_request --

  def test_around_request_yields_original_request_for_non_get_head_requests
    response = make_response(req: post_request)
    yielded_request = nil
    result = feature.around_request(post_request) do |req|
      yielded_request = req
      response
    end

    assert_same response, result
    assert_same post_request, yielded_request
  end

  def test_around_request_does_not_consult_store_for_non_cacheable_methods
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

  def test_around_request_yields_original_request_when_no_cache_entry_exists
    response = make_response
    yielded_request = nil
    result = feature.around_request(request) do |req|
      yielded_request = req
      response
    end

    assert_same response, result
    assert_same request, yielded_request
  end

  def test_around_request_with_fresh_cached_entry_returns_cached_response_without_yielding
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

  def test_around_request_with_fresh_cached_entry_preserves_proxy_headers
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

  def test_around_request_with_stale_entry_adds_if_none_match_header_when_entry_has_etag
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
    assert_nil request.headers["If-None-Match"]
  end

  def test_around_request_with_stale_entry_does_not_add_if_none_match_when_entry_has_no_etag
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

  def test_around_request_with_stale_entry_adds_if_modified_since_when_entry_has_last_modified
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

  def test_around_request_with_stale_entry_does_not_add_if_modified_since_when_no_last_modified
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

  def test_around_request_with_stale_entry_preserves_request_properties_in_revalidation
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

  def test_around_request_with_stale_entry_returns_cached_response_on_304_and_updates_stored_at
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
    assert_operator entry.stored_at, :>, old_stored_at
  end

  def test_around_request_with_stale_entry_merges_304_response_headers_into_cached_entry
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

  def test_around_request_with_stale_entry_returns_new_response_on_non_304
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

  def test_around_request_with_stale_entry_uses_status_predicate_to_detect_304
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

    ok_response = make_response(status: 200, body: "new body")
    result = feature.around_request(request) { ok_response }

    assert_same ok_response, result
  end

  def test_around_request_caches_head_requests
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

  # -- #wrap_response --

  def test_wrap_response_stores_cacheable_responses_and_returns_correct_properties
    response = make_response(headers: { "Cache-Control" => "max-age=3600" })
    result = feature.wrap_response(response)

    assert store.lookup(request)
    assert_equal 200, result.status.code
    assert_equal "1.1", result.version
    assert_equal "hello", result.body.to_s
    assert_same request, result.request
  end

  def test_wrap_response_preserves_headers_in_stored_response
    response = make_response(headers: { "Cache-Control" => "max-age=3600", "X-Custom" => "value" })
    result = feature.wrap_response(response)

    assert_equal "value", result.headers["X-Custom"]
  end

  def test_wrap_response_preserves_proxy_headers_in_stored_response
    response = make_response(
      headers:       { "Cache-Control" => "max-age=3600" },
      proxy_headers: { "X-Proxy" => "test-value" }
    )
    result = feature.wrap_response(response)

    assert_equal "test-value", result.proxy_headers["X-Proxy"]
  end

  def test_wrap_response_does_not_store_responses_with_no_store
    response = make_response(headers: { "Cache-Control" => "no-store" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_does_not_store_non_cacheable_status_codes_500
    response = make_response(status: 500, headers: { "Cache-Control" => "max-age=60" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_does_not_store_400_responses
    response = make_response(status: 400, headers: { "Cache-Control" => "max-age=60" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_stores_399_responses
    response = make_response(status: 399, headers: { "Cache-Control" => "max-age=60" })
    feature.wrap_response(response)

    assert store.lookup(request)
  end

  def test_wrap_response_does_not_store_1xx_responses
    response = make_response(status: 100, headers: { "Cache-Control" => "max-age=60" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_does_not_store_199_responses
    response = make_response(status: 199, headers: { "Cache-Control" => "max-age=60" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_stores_200_responses
    response = make_response(status: 200, headers: { "Cache-Control" => "max-age=60" })
    feature.wrap_response(response)

    assert store.lookup(request)
  end

  def test_wrap_response_does_not_store_post_responses
    response = make_response(
      headers: { "Cache-Control" => "max-age=3600" },
      req:     post_request
    )
    result = feature.wrap_response(response)

    assert_same response, result
    assert_nil store.lookup(post_request)
  end

  def test_wrap_response_returns_original_response_for_non_cacheable_responses
    response = make_response(headers: { "Cache-Control" => "no-store" })
    result = feature.wrap_response(response)

    assert_same response, result
  end

  def test_wrap_response_stores_response_with_etag
    response = make_response(headers: { "ETag" => '"v1"' })
    feature.wrap_response(response)

    assert store.lookup(request)
  end

  def test_wrap_response_stores_response_with_last_modified
    response = make_response(headers: { "Last-Modified" => "Wed, 01 Jan 2025 00:00:00 GMT" })
    feature.wrap_response(response)

    assert store.lookup(request)
  end

  def test_wrap_response_stores_response_with_expires
    response = make_response(headers: { "Expires" => "Thu, 01 Jan 2099 00:00:00 GMT" })
    feature.wrap_response(response)

    assert store.lookup(request)
  end

  def test_wrap_response_does_not_store_response_without_freshness_info
    response = make_response(headers: {})
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_does_not_treat_non_max_age_directives_as_freshness_info
    response = make_response(headers: { "Cache-Control" => "public" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_preserves_uri_in_stored_response
    response = make_response(headers: { "Cache-Control" => "max-age=3600" })
    result = feature.wrap_response(response)

    assert_equal request.uri, result.uri
  end

  def test_wrap_response_returns_a_response_with_string_body
    response = make_response(headers: { "Cache-Control" => "max-age=3600" }, body: "hello")
    result = feature.wrap_response(response)

    assert_equal "hello", result.body.to_s
  end

  def test_wrap_response_eagerly_reads_streaming_body_into_a_string
    response = make_streaming_response(
      headers: { "Cache-Control" => "max-age=3600" },
      content: "streamed content"
    )
    result = feature.wrap_response(response)

    assert_instance_of String, result.body
    assert_equal "streamed content", result.body
  end

  def test_wrap_response_stores_301_redirect_responses
    response = make_response(
      status:  301,
      headers: { "Cache-Control" => "max-age=3600", "Location" => "https://example.com/new" }
    )
    feature.wrap_response(response)

    assert store.lookup(request)
  end

  def test_wrap_response_stores_entry_with_correct_properties
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

  def test_wrap_response_does_not_store_no_store_even_when_freshness_info_present
    response = make_response(headers: { "Cache-Control" => "no-store, max-age=3600" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_does_not_store_no_store_with_etag
    response = make_response(headers: { "Cache-Control" => "no-store", "ETag" => '"v1"' })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_handles_uppercase_no_store_with_freshness_info
    response = make_response(headers: { "Cache-Control" => "NO-STORE", "ETag" => '"v1"' })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_handles_cache_control_with_spaces_around_commas
    response = make_response(headers: { "Cache-Control" => "max-age=3600 , no-store" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_handles_no_store_with_trailing_whitespace_before_comma
    response = make_response(headers: { "Cache-Control" => "no-store , max-age=3600" })
    feature.wrap_response(response)

    assert_nil store.lookup(request)
  end

  def test_wrap_response_dups_headers_in_stored_entry_to_prevent_mutation
    response = make_response(headers: { "Cache-Control" => "max-age=3600", "X-Custom" => "original" })
    feature.wrap_response(response)

    entry = store.lookup(request)
    entry.headers["X-Custom"] = "mutated"

    assert_equal "original", response.headers["X-Custom"]
  end

  def test_wrap_response_stores_proxy_headers_in_entry
    response = make_response(
      headers:       { "Cache-Control" => "max-age=3600" },
      proxy_headers: { "X-Proxy" => "stored-proxy" }
    )
    feature.wrap_response(response)
    entry = store.lookup(request)

    assert_equal "stored-proxy", entry.proxy_headers["X-Proxy"]
  end

  def test_wrap_response_stores_entry_with_integer_status_code
    response = make_response(status: 200, headers: { "Cache-Control" => "max-age=3600" })
    feature.wrap_response(response)
    entry = store.lookup(request)

    assert_instance_of Integer, entry.status
  end

  # -- feature registration --

  def test_feature_registration_is_registered_as_caching
    assert_equal HTTP::Features::Caching, HTTP::Options.available_features[:caching]
  end
end

class HTTPFeaturesCachingEntryTest < Minitest::Test
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

  # -- #fresh? --

  def test_fresh_when_max_age_has_not_elapsed
    entry = make_entry(headers: { "Cache-Control" => "max-age=3600" })

    assert_predicate entry, :fresh?
  end

  def test_not_fresh_when_max_age_has_elapsed
    entry = make_entry(
      headers:   { "Cache-Control" => "max-age=60" },
      stored_at: Time.now - 120
    )

    refute_predicate entry, :fresh?
  end

  def test_fresh_when_expires_is_in_the_future
    entry = make_entry(headers: { "Expires" => (Time.now + 3600).httpdate })

    assert_predicate entry, :fresh?
  end

  def test_not_fresh_when_expires_is_in_the_past
    entry = make_entry(headers: { "Expires" => (Time.now - 3600).httpdate })

    refute_predicate entry, :fresh?
  end

  def test_not_fresh_when_no_cache_is_present
    entry = make_entry(headers: { "Cache-Control" => "max-age=3600, no-cache" })

    refute_predicate entry, :fresh?
  end

  def test_not_fresh_when_no_cache_is_present_in_uppercase
    entry = make_entry(headers: { "Cache-Control" => "max-age=3600, NO-CACHE" })

    refute_predicate entry, :fresh?
  end

  def test_not_fresh_without_any_freshness_info
    entry = make_entry(headers: {})

    refute_predicate entry, :fresh?
  end

  def test_accounts_for_age_header_in_freshness
    entry = make_entry(headers: { "Cache-Control" => "max-age=100", "Age" => "90" })

    assert_predicate entry, :fresh?
  end

  def test_not_fresh_when_age_exceeds_max_age
    entry = make_entry(headers: { "Cache-Control" => "max-age=100", "Age" => "200" })

    refute_predicate entry, :fresh?
  end

  def test_treats_age_as_float_for_precision
    entry = make_entry(headers: { "Cache-Control" => "max-age=100", "Age" => "99" })

    assert_predicate entry, :fresh?
  end

  def test_defaults_base_age_to_zero_when_no_age_header
    entry = make_entry(headers: { "Cache-Control" => "max-age=1" })

    assert_predicate entry, :fresh?
  end

  def test_handles_non_numeric_age_header_gracefully
    entry = make_entry(headers: { "Cache-Control" => "max-age=3600", "Age" => "abc" })

    assert_predicate entry, :fresh?
  end

  def test_treats_non_numeric_age_as_zero_for_freshness_calculation
    entry = make_entry(
      headers:   { "Cache-Control" => "max-age=100", "Age" => "abc" },
      stored_at: Time.now - 100.5
    )

    refute_predicate entry, :fresh?
  end

  def test_handles_invalid_expires_gracefully
    entry = make_entry(headers: { "Expires" => "not-a-date" })

    refute_predicate entry, :fresh?
  end

  def test_falls_through_to_expires_when_cache_control_has_no_max_age
    entry = make_entry(headers: {
      "Cache-Control" => "public",
      "Expires"       => (Time.now + 3600).httpdate
    })

    assert_predicate entry, :fresh?
  end

  def test_prefers_max_age_over_expires_when_both_present
    entry = make_entry(
      headers:   { "Cache-Control" => "max-age=0", "Expires" => (Time.now + 3600).httpdate },
      stored_at: Time.now - 1
    )

    refute_predicate entry, :fresh?
  end

  # -- #update_headers! --

  def test_update_headers_merges_new_headers_into_entry
    entry = make_entry(headers: { "ETag" => '"old"', "X-Keep" => "kept" })
    new_headers = HTTP::Headers.coerce("ETag" => '"new"', "X-Added" => "added")
    entry.update_headers!(new_headers)

    assert_equal '"new"', entry.headers["ETag"]
    assert_equal "added", entry.headers["X-Added"]
    assert_equal "kept", entry.headers["X-Keep"]
  end

  def test_update_headers_overwrites_existing_headers_with_304_values
    entry = make_entry(headers: { "Cache-Control" => "max-age=60" })
    new_headers = HTTP::Headers.coerce("Cache-Control" => "max-age=120")
    entry.update_headers!(new_headers)

    assert_equal "max-age=120", entry.headers["Cache-Control"]
  end

  # -- #revalidate! --

  def test_revalidate_resets_stored_at_to_current_time
    old_time = Time.now - 1000
    entry = make_entry(stored_at: old_time)
    entry.revalidate!

    assert_operator entry.stored_at, :>, old_time
  end

  # -- attribute readers --

  def test_exposes_status
    entry = make_entry

    assert_equal 200, entry.status
  end

  def test_exposes_version
    entry = make_entry

    assert_equal "1.1", entry.version
  end

  def test_exposes_body
    entry = make_entry

    assert_equal "body", entry.body
  end

  def test_exposes_request_uri
    entry = make_entry

    assert_equal HTTP::URI.parse("https://example.com/"), entry.request_uri
  end

  def test_exposes_proxy_headers
    entry = make_entry

    assert_instance_of HTTP::Headers, entry.proxy_headers
  end
end

class HTTPFeaturesCachingInMemoryStoreTest < Minitest::Test
  cover "HTTP::Features::Caching::InMemoryStore*"

  def store
    @store ||= HTTP::Features::Caching::InMemoryStore.new
  end

  def request
    @request ||= HTTP::Request.new(verb: :get, uri: "https://example.com/resource")
  end

  def entry
    @entry ||= HTTP::Features::Caching::Entry.new(
      status:        200,
      version:       "1.1",
      headers:       HTTP::Headers.coerce({}),
      proxy_headers: HTTP::Headers.coerce({}),
      body:          "test",
      request_uri:   request.uri,
      stored_at:     Time.now
    )
  end

  # -- #lookup --

  def test_lookup_returns_nil_for_unknown_requests
    assert_nil store.lookup(request)
  end

  def test_lookup_returns_stored_entry
    store.store(request, entry)

    assert_same entry, store.lookup(request)
  end

  # -- #store --

  def test_store_stores_and_retrieves_by_request_method_and_uri
    store.store(request, entry)

    assert_same entry, store.lookup(request)
  end

  def test_store_stores_different_entries_for_different_uris
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

  def test_store_stores_different_entries_for_different_verbs
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

  def test_store_replaces_existing_entry
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

  def test_store_finds_entry_using_different_request_object_with_same_verb_and_uri
    store.store(request, entry)
    same_request = HTTP::Request.new(verb: :get, uri: "https://example.com/resource")

    assert_same entry, store.lookup(same_request)
  end
end
