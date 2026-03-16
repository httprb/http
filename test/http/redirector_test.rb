# frozen_string_literal: true

require "test_helper"

class HTTPRedirectorTest < Minitest::Test
  cover "HTTP::Redirector*"

  def simple_response(status, body = "", headers = {})
    HTTP::Response.new(
      status:  status,
      version: "1.1",
      headers: headers,
      body:    body,
      request: HTTP::Request.new(verb: :get, uri: "http://example.com")
    )
  end

  def redirect_response(status, location)
    simple_response status, "", "Location" => location
  end

  # #strict

  def test_strict_returns_true_by_default
    redirector = HTTP::Redirector.new

    assert redirector.strict
  end

  # #max_hops

  def test_max_hops_returns_5_by_default
    redirector = HTTP::Redirector.new

    assert_equal 5, redirector.max_hops
  end

  def test_max_hops_coerces_string_value_to_integer
    redirector = HTTP::Redirector.new(max_hops: "3")

    assert_equal 3, redirector.max_hops
  end

  # #perform

  def test_perform_fails_with_too_many_redirects_error_if_max_hops_reached
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    res = proc { |prev_req| redirect_response(301, "#{prev_req.uri}/1") }

    assert_raises(HTTP::Redirector::TooManyRedirectsError) do
      redirector.perform(req, res.call(req), &res)
    end
  end

  def test_perform_fails_with_endless_redirect_error_if_endless_loop_detected
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    res = redirect_response(301, req.uri)

    assert_raises(HTTP::Redirector::EndlessRedirectError) do
      redirector.perform(req, res) { res }
    end
  end

  def test_perform_fails_with_state_error_if_no_location_header
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    res = simple_response(301)

    assert_raises(HTTP::StateError) do
      redirector.perform(req, res) { |_| nil }
    end
  end

  def test_perform_returns_first_non_redirect_response
    redirector = HTTP::Redirector.new
    req  = HTTP::Request.new verb: :head, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      redirect_response(301, "http://example.com/2"),
      redirect_response(301, "http://example.com/3"),
      simple_response(200, "foo"),
      redirect_response(301, "http://example.com/4"),
      simple_response(200, "bar")
    ]

    res = redirector.perform(req, hops.shift) { hops.shift }

    assert_equal "foo", res.to_s
  end

  def test_perform_concatenates_multiple_location_headers
    redirector = HTTP::Redirector.new
    req     = HTTP::Request.new verb: :head, uri: "http://example.com"
    headers = HTTP::Headers.new

    %w[http://example.com /123].each { |loc| headers.add("Location", loc) }

    res = redirector.perform(req, simple_response(301, "", headers)) do |redirect|
      simple_response(200, redirect.uri.to_s)
    end

    assert_equal "http://example.com/123", res.to_s
  end

  # on_redirect callback

  def test_perform_with_on_redirect_calls_on_redirect
    redirect_response_captured = nil
    redirect_location_captured = nil
    redirector = HTTP::Redirector.new(
      on_redirect: proc do |response, location|
        redirect_response_captured = response
        redirect_location_captured = location
      end
    )

    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      redirect_response(301, "http://example.com/2"),
      simple_response(200, "foo")
    ]

    redirector.perform(req, hops.shift) do |prev_req, _|
      assert_equal prev_req.uri.to_s, redirect_location_captured.uri.to_s
      assert_equal 301, redirect_response_captured.code
      hops.shift
    end
  end

  # following 300, 301, 302 redirects (strict mode)

  unsafe_verbs = %i[put post delete]

  [300, 301, 302].each do |status_code|
    define_method(:"test_following_#{status_code}_strict_follows_with_original_verb_if_safe") do
      redirector = HTTP::Redirector.new(strict: true)
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      res = redirect_response status_code, "http://example.com/1"

      redirector.perform(req, res) do |prev_req, _|
        assert_equal :head, prev_req.verb
        simple_response 200
      end
    end

    unsafe_verbs.each do |verb|
      define_method(:"test_following_#{status_code}_strict_raises_state_error_for_#{verb}") do
        redirector = HTTP::Redirector.new(strict: true)
        req = HTTP::Request.new verb: verb, uri: "http://example.com"
        res = redirect_response status_code, "http://example.com/1"

        assert_raises(HTTP::StateError) do
          redirector.perform(req, res) { simple_response 200 }
        end
      end
    end

    define_method(:"test_following_#{status_code}_non_strict_follows_with_original_verb_if_safe") do
      redirector = HTTP::Redirector.new(strict: false)
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      res = redirect_response status_code, "http://example.com/1"

      redirector.perform(req, res) do |prev_req, _|
        assert_equal :head, prev_req.verb
        simple_response 200
      end
    end

    unsafe_verbs.each do |verb|
      define_method(:"test_following_#{status_code}_non_strict_follows_with_get_for_#{verb}") do
        redirector = HTTP::Redirector.new(strict: false)
        req = HTTP::Request.new verb: verb, uri: "http://example.com"
        res = redirect_response status_code, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :get, prev_req.verb
          simple_response 200
        end
      end
    end
  end

  # following 303 redirect

  def test_following_303_follows_with_head_if_original_request_was_head
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    res = redirect_response 303, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal :head, prev_req.verb
      simple_response 200
    end
  end

  def test_following_303_follows_with_get_if_original_request_was_get
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    res = redirect_response 303, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal :get, prev_req.verb
      simple_response 200
    end
  end

  def test_following_303_follows_with_get_if_original_request_was_neither_get_nor_head
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :post, uri: "http://example.com"
    res = redirect_response 303, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal :get, prev_req.verb
      simple_response 200
    end
  end

  # following 307 redirect

  def test_following_307_follows_with_original_requests_verb
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :post, uri: "http://example.com"
    res = redirect_response 307, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal :post, prev_req.verb
      simple_response 200
    end
  end

  # following 308 redirect

  def test_following_308_follows_with_original_requests_verb
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :post, uri: "http://example.com"
    res = redirect_response 308, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal :post, prev_req.verb
      simple_response 200
    end
  end

  # changing verbs during redirects

  def test_changing_verbs_follows_without_body_content_type_if_it_has_to_change_verb
    redirector = HTTP::Redirector.new(strict: false)
    post_body = HTTP::Request::Body.new("i might be way longer in real life")
    cookie = "dont=eat my cookies"

    req = HTTP::Request.new(
      verb: :post, uri: "http://example.com",
      body: post_body, headers: {
        "Content-Type" => "meme",
        "Cookie"       => cookie
      }
    )
    res = redirect_response 302, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal HTTP::Request::Body.new(nil), prev_req.body
      assert_equal cookie, prev_req.headers["Cookie"]
      assert_nil prev_req.headers["Content-Type"]
      simple_response 200
    end
  end

  def test_changing_verbs_leaves_body_content_type_intact_if_it_does_not_have_to_change_verb
    redirector = HTTP::Redirector.new(strict: false)
    post_body = HTTP::Request::Body.new("i might be way longer in real life")
    cookie = "dont=eat my cookies"

    req = HTTP::Request.new(
      verb: :post, uri: "http://example.com",
      body: post_body, headers: {
        "Content-Type" => "meme",
        "Cookie"       => cookie
      }
    )
    res = redirect_response 307, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal post_body, prev_req.body
      assert_equal cookie, prev_req.headers["Cookie"]
      assert_equal "meme", prev_req.headers["Content-Type"]
      simple_response 200
    end
  end

  # max_hops: 0

  def test_with_max_hops_0_does_not_limit_redirects
    redirector = HTTP::Redirector.new(max_hops: 0)
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    hops = (1..10).map { |i| redirect_response(301, "http://example.com/#{i}") }
    hops << simple_response(200, "done")

    res = redirector.perform(req, hops.shift) { hops.shift }

    assert_equal "done", res.to_s
  end

  # max_hops: 1

  def test_with_max_hops_1_allows_exactly_one_redirect
    redirector = HTTP::Redirector.new(max_hops: 1)
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      simple_response(200, "one hop")
    ]

    res = redirector.perform(req, hops.shift) { hops.shift }

    assert_equal "one hop", res.to_s
  end

  def test_with_max_hops_1_raises_too_many_redirects_error_on_the_second_redirect
    redirector = HTTP::Redirector.new(max_hops: 1)
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      redirect_response(301, "http://example.com/2"),
      simple_response(200, "unreachable")
    ]

    assert_raises(HTTP::Redirector::TooManyRedirectsError) do
      redirector.perform(req, hops.shift) { hops.shift }
    end
  end

  # with :get verb on strict-sensitive codes

  [300, 301, 302].each do |status_code|
    define_method(:"test_strict_follows_#{status_code}_redirect_with_get_verb_without_raising") do
      redirector = HTTP::Redirector.new(strict: true)
      req = HTTP::Request.new verb: :get, uri: "http://example.com"
      res = redirect_response status_code, "http://example.com/1"

      result = redirector.perform(req, res) do |prev_req, _|
        assert_equal :get, prev_req.verb
        simple_response 200, "ok"
      end

      assert_equal "ok", result.to_s
    end
  end

  # following 303 redirect with unsafe verbs

  def test_following_303_follows_with_get_if_original_request_was_put
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :put, uri: "http://example.com"
    res = redirect_response 303, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal :get, prev_req.verb
      simple_response 200
    end
  end

  def test_following_303_follows_with_get_if_original_request_was_delete
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :delete, uri: "http://example.com"
    res = redirect_response 303, "http://example.com/1"

    redirector.perform(req, res) do |prev_req, _|
      assert_equal :get, prev_req.verb
      simple_response 200
    end
  end

  # on_redirect callback behavior

  def test_on_redirect_passes_both_response_and_request_to_on_redirect
    captured_response = nil
    captured_request = nil
    redirector = HTTP::Redirector.new(
      on_redirect: proc do |response, request|
        captured_response = response
        captured_request = request
      end
    )

    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      simple_response(200, "done")
    ]

    redirector.perform(req, hops.shift) { hops.shift }

    refute_nil captured_response
    refute_nil captured_request
    assert_equal 301, captured_response.code
    assert_equal "http://example.com/1", captured_request.uri.to_s
  end

  def test_on_redirect_works_without_on_redirect_callback
    redirector = HTTP::Redirector.new

    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      simple_response(200, "done")
    ]

    res = redirector.perform(req, hops.shift) { hops.shift }

    assert_equal "done", res.to_s
  end

  def test_on_redirect_works_when_on_redirect_is_explicitly_nil
    redirector = HTTP::Redirector.new(on_redirect: nil)

    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      simple_response(200, "done")
    ]

    res = redirector.perform(req, hops.shift) { hops.shift }

    assert_equal "done", res.to_s
  end

  # block yielding

  def test_perform_yields_the_request_to_the_block
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    hops = [
      redirect_response(301, "http://example.com/1"),
      simple_response(200, "done")
    ]

    yielded_request = nil
    redirector.perform(req, hops.shift) do |r|
      yielded_request = r
      hops.shift
    end

    refute_nil yielded_request
    assert_equal "http://example.com/1", yielded_request.uri.to_s
  end

  # flush

  def test_perform_calls_flush_on_intermediate_redirect_responses
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    res = redirect_response(301, "http://example.com/1")

    flushed = false
    original_flush = res.method(:flush)
    res.define_singleton_method(:flush) do
      flushed = true
      original_flush.call
    end

    redirector.perform(req, res) { simple_response(200, "done") }

    assert flushed, "expected response.flush to be called during redirect"
  end

  # endless redirect detection

  def test_perform_tracks_visited_urls_with_verb_uri_and_cookies
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    res = redirect_response(301, "http://example.com")

    err = assert_raises(HTTP::Redirector::EndlessRedirectError) do
      redirector.perform(req, res) { redirect_response(301, "http://example.com") }
    end
    assert_kind_of HTTP::Redirector::TooManyRedirectsError, err
  end

  def test_perform_does_not_falsely_detect_endless_loop_when_cookies_change
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    res = redirect_response(302, "http://example.com")

    call_count = 0
    result = redirector.perform(req, res) do |redirect_req|
      call_count += 1
      redirect_req.headers.set("Cookie", "auth=ok")
      if call_count == 1
        redirect_response(302, "http://example.com")
      else
        simple_response(200, "authenticated")
      end
    end

    assert_equal 2, call_count
    assert_equal "authenticated", result.to_s
  end

  def test_perform_raises_state_error_with_descriptive_message_when_no_location_header
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    res = simple_response(301)

    err = assert_raises(HTTP::StateError) do
      redirector.perform(req, res) { |_| nil }
    end
    assert_match(/no Location header/, err.message)
  end

  # strict mode StateError messages

  def test_strict_mode_includes_status_in_the_error_message
    redirector = HTTP::Redirector.new(strict: true)
    req = HTTP::Request.new verb: :post, uri: "http://example.com"
    res = redirect_response 301, "http://example.com/1"

    err = assert_raises(HTTP::StateError) do
      redirector.perform(req, res) { simple_response 200 }
    end
    assert_match(/301/, err.message)
  end

  # max_hops: 2 with endless redirect loop

  def test_with_max_hops_2_detects_endless_loop_before_reaching_max_hops
    redirector = HTTP::Redirector.new(max_hops: 2)
    req = HTTP::Request.new verb: :head, uri: "http://example.com"
    res = redirect_response(301, "http://example.com")

    assert_raises(HTTP::Redirector::EndlessRedirectError) do
      redirector.perform(req, res) { redirect_response(301, "http://example.com") }
    end
  end

  def test_perform_detects_endless_loop_when_repeated_url_is_not_the_first_one_visited
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://a.example.com"
    hops = [
      redirect_response(301, "http://b.example.com"),
      redirect_response(301, "http://c.example.com"),
      redirect_response(301, "http://b.example.com"),
      redirect_response(301, "http://d.example.com"),
      simple_response(200, "unreachable")
    ]

    assert_raises(HTTP::Redirector::EndlessRedirectError) do
      redirector.perform(req, hops.shift) { hops.shift }
    end
  end

  # sensitive headers

  def test_sensitive_headers_preserves_authorization_and_cookie_when_redirecting_to_same_origin
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    req.headers.set("Authorization", "Bearer secret")
    req.headers.set("Cookie", "session=abc")
    hops = [
      redirect_response(301, "http://example.com/other"),
      simple_response(200, "done")
    ]

    redirector.perform(req, hops.shift) do |request|
      assert_equal "Bearer secret", request.headers["Authorization"]
      assert_equal "session=abc", request.headers["Cookie"]
      hops.shift
    end
  end

  def test_sensitive_headers_strips_authorization_and_cookie_when_redirecting_to_different_host
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    req.headers.set("Authorization", "Bearer secret")
    req.headers.set("Cookie", "session=abc")
    hops = [
      redirect_response(301, "http://other.example.com/"),
      simple_response(200, "done")
    ]

    redirector.perform(req, hops.shift) do |request|
      assert_nil request.headers["Authorization"]
      assert_nil request.headers["Cookie"]
      hops.shift
    end
  end

  def test_sensitive_headers_strips_authorization_and_cookie_when_redirecting_to_different_scheme
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    req.headers.set("Authorization", "Bearer secret")
    req.headers.set("Cookie", "session=abc")
    hops = [
      redirect_response(301, "https://example.com/"),
      simple_response(200, "done")
    ]

    redirector.perform(req, hops.shift) do |request|
      assert_nil request.headers["Authorization"]
      assert_nil request.headers["Cookie"]
      hops.shift
    end
  end

  def test_sensitive_headers_strips_authorization_and_cookie_when_redirecting_to_different_port
    redirector = HTTP::Redirector.new
    req = HTTP::Request.new verb: :get, uri: "http://example.com"
    req.headers.set("Authorization", "Bearer secret")
    req.headers.set("Cookie", "session=abc")
    hops = [
      redirect_response(301, "http://example.com:8080/"),
      simple_response(200, "done")
    ]

    redirector.perform(req, hops.shift) do |request|
      assert_nil request.headers["Authorization"]
      assert_nil request.headers["Cookie"]
      hops.shift
    end
  end

  # verb change does not cause false endless loop detection

  def test_perform_does_not_falsely_detect_endless_loop_when_verb_changes_for_same_url
    req = HTTP::Request.new verb: :post, uri: "http://example.com"
    hops = [
      redirect_response(302, "http://example.com/done"),
      simple_response(200, "done")
    ]

    res = HTTP::Redirector.new(strict: false, max_hops: 5).perform(
      req, redirect_response(302, "http://example.com")
    ) { hops.shift }

    assert_equal "done", res.to_s
  end
end
