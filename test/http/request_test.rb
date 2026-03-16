# frozen_string_literal: true

require "test_helper"

class HTTPRequestTest < Minitest::Test
  cover "HTTP::Request*"

  def build_request(verb: :get, uri: "http://example.com/foo?bar=baz", headers: { accept: "text/html" }, proxy: {},
                    **)
    HTTP::Request.new(verb: verb, uri: uri, headers: headers, proxy: proxy, **)
  end

  # #initialize

  def test_initialize_provides_a_headers_accessor
    assert_kind_of HTTP::Headers, build_request.headers
  end

  def test_initialize_provides_a_scheme_accessor
    assert_equal :http, build_request.scheme
  end

  def test_initialize_provides_a_verb_accessor
    assert_equal :get, build_request.verb
  end

  def test_initialize_provides_a_uri_accessor
    assert_equal HTTP::URI.parse("http://example.com/foo?bar=baz"), build_request.uri
  end

  def test_initialize_provides_a_proxy_accessor
    assert_equal({}, build_request.proxy)
  end

  def test_initialize_provides_a_version_accessor_defaulting_to_1_1
    assert_equal "1.1", build_request.version
  end

  def test_initialize_provides_a_body_accessor
    assert_instance_of HTTP::Request::Body, build_request.body
  end

  def test_initialize_provides_a_uri_normalizer_accessor
    assert_equal HTTP::URI::NORMALIZER, build_request.uri_normalizer
  end

  def test_initialize_stores_a_custom_uri_normalizer
    custom = ->(uri) { HTTP::URI.parse(uri) }
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/", uri_normalizer: custom)

    assert_equal custom, req.uri_normalizer
  end

  def test_initialize_stores_a_custom_version
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/", version: "2.0")

    assert_equal "2.0", req.version
  end

  def test_initialize_stores_the_proxy_hash
    p = { proxy_address: "proxy.example.com", proxy_port: 8080 }
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/", proxy: p)

    assert_equal p, req.proxy
  end

  def test_initialize_downcases_and_symbolizes_the_verb
    req = HTTP::Request.new(verb: "POST", uri: "http://example.com/")

    assert_equal :post, req.verb
  end

  def test_initialize_downcases_the_scheme
    req = HTTP::Request.new(verb: :get, uri: "HTTP://example.com/")

    assert_equal :http, req.scheme
  end

  def test_initialize_accepts_https_scheme
    req = HTTP::Request.new(verb: :get, uri: "https://example.com/")

    assert_equal :https, req.scheme
  end

  def test_initialize_accepts_ws_scheme
    req = HTTP::Request.new(verb: :get, uri: "ws://example.com/")

    assert_equal :ws, req.scheme
  end

  def test_initialize_accepts_wss_scheme
    req = HTTP::Request.new(verb: :get, uri: "wss://example.com/")

    assert_equal :wss, req.scheme
  end

  def test_initialize_stores_body_source
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "hello")

    assert_equal "hello", req.body.source
  end

  def test_initialize_wraps_non_body_body_in_body_object
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "hello")

    assert_instance_of HTTP::Request::Body, req.body
  end

  def test_initialize_passes_through_an_existing_body_object
    existing_body = HTTP::Request::Body.new("hello")
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: existing_body)

    assert_same existing_body, req.body
  end

  def test_initialize_passes_through_a_body_subclass
    subclass_body = Class.new(HTTP::Request::Body).new("hello")
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: subclass_body)

    assert_same subclass_body, req.body
  end

  def test_initialize_sets_given_headers
    assert_equal "text/html", build_request.headers["Accept"]
  end

  def test_initialize_raises_invalid_error_for_uri_without_scheme
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::Request.new(verb: :get, uri: "example.com/")
    end
    assert_match(/invalid URI/, err.message)
  end

  def test_initialize_raises_argument_error_for_nil_uri
    err = assert_raises(ArgumentError) do
      HTTP::Request.new(verb: :get, uri: nil)
    end
    assert_equal "uri is nil", err.message
  end

  def test_initialize_raises_argument_error_for_empty_string_uri
    err = assert_raises(ArgumentError) do
      HTTP::Request.new(verb: :get, uri: "")
    end
    assert_equal "uri is empty", err.message
  end

  def test_initialize_does_not_raise_for_non_string_non_empty_uri_like_objects
    uri = HTTP::URI.parse("http://example.com/")
    req = HTTP::Request.new(verb: :get, uri: uri)

    assert_equal :http, req.scheme
  end

  def test_initialize_raises_invalid_error_for_malformed_uri
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::Request.new(verb: :get, uri: ":")
    end
    assert_match(/invalid URI/, err.message)
  end

  def test_initialize_raises_unsupported_scheme_error_for_unsupported_scheme
    err = assert_raises(HTTP::Request::UnsupportedSchemeError) do
      HTTP::Request.new(verb: :get, uri: "ftp://example.com/")
    end
    assert_match(/unknown scheme/, err.message)
  end

  def test_initialize_raises_unsupported_method_error_for_unknown_verbs
    err = assert_raises(HTTP::Request::UnsupportedMethodError) do
      HTTP::Request.new(verb: :foobar, uri: "http://example.com/")
    end
    assert_match(/unknown method/, err.message)
  end

  def test_initialize_includes_verb_in_unsupported_method_error_message
    err = assert_raises(HTTP::Request::UnsupportedMethodError) do
      HTTP::Request.new(verb: :foobar, uri: "http://example.com/")
    end

    assert_includes err.message, "foobar"
  end

  def test_initialize_includes_uri_in_invalid_error_message_for_missing_scheme
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::Request.new(verb: :get, uri: "example.com/")
    end

    assert_includes err.message, "example.com/"
  end

  def test_initialize_includes_scheme_in_unsupported_scheme_error_message
    err = assert_raises(HTTP::Request::UnsupportedSchemeError) do
      HTTP::Request.new(verb: :get, uri: "ftp://example.com/")
    end

    assert_includes err.message, "ftp"
  end

  def test_initialize_defaults_proxy_to_an_empty_hash
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

    assert_equal({}, req.proxy)
  end

  def test_initialize_sets_default_headers_when_headers_arg_is_nil
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

    assert_equal "example.com", req.headers["Host"]
    assert_equal HTTP::Request::USER_AGENT, req.headers["User-Agent"]
  end

  # Host header

  def test_host_header_defaults_to_the_host_from_the_uri
    assert_equal "example.com", build_request.headers["Host"]
  end

  def test_host_header_with_non_standard_port_includes_the_port
    request = build_request(uri: "http://example.com:3000/")

    assert_equal "example.com:3000", request.headers["Host"]
  end

  def test_host_header_with_standard_https_port_omits_the_port
    request = build_request(uri: "https://example.com/")

    assert_equal "example.com", request.headers["Host"]
  end

  def test_host_header_with_non_standard_https_port_includes_the_port
    request = build_request(uri: "https://example.com:8443/")

    assert_equal "example.com:8443", request.headers["Host"]
  end

  def test_host_header_when_explicitly_given_uses_the_given_host
    request = build_request(headers: { accept: "text/html", host: "github.com" })

    assert_equal "github.com", request.headers["Host"]
  end

  def test_host_header_when_host_contains_whitespace_raises_request_error
    normalizer = lambda { |uri|
      u = HTTP::URI.parse(uri)
      u.host = "exam ple.com"
      u
    }

    assert_raises(HTTP::RequestError) do
      HTTP::Request.new(verb: :get, uri: "http://example.com/", uri_normalizer: normalizer)
    end
  end

  def test_host_header_when_host_contains_whitespace_includes_invalid_host_in_error
    normalizer = lambda { |uri|
      u = HTTP::URI.parse(uri)
      u.host = "exam ple.com"
      u
    }

    err = assert_raises(HTTP::RequestError) do
      HTTP::Request.new(verb: :get, uri: "http://example.com/", uri_normalizer: normalizer)
    end

    assert_includes err.message, "exam ple.com".inspect
  end

  # User-Agent header

  def test_user_agent_header_defaults_to_http_request_user_agent
    assert_equal HTTP::Request::USER_AGENT, build_request.headers["User-Agent"]
  end

  def test_user_agent_header_when_explicitly_given_uses_it
    request = build_request(headers: { accept: "text/html", user_agent: "MrCrawly/123" })

    assert_equal "MrCrawly/123", request.headers["User-Agent"]
  end

  # #using_proxy?

  def test_using_proxy_with_empty_proxy_hash_returns_false
    refute_predicate build_request(proxy: {}), :using_proxy?
  end

  def test_using_proxy_with_one_key_in_proxy_returns_false
    refute_predicate build_request(proxy: { proxy_address: "proxy.example.com" }), :using_proxy?
  end

  def test_using_proxy_with_two_keys_in_proxy_returns_true
    assert_predicate build_request(proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }), :using_proxy?
  end

  def test_using_proxy_with_four_keys_in_proxy_returns_true
    proxy = { proxy_address: "proxy.example.com", proxy_port: 8080,
              proxy_username: "user", proxy_password: "pass" }

    assert_predicate build_request(proxy: proxy), :using_proxy?
  end

  # #using_authenticated_proxy?

  def test_using_authenticated_proxy_with_empty_proxy_hash_returns_false
    refute_predicate build_request(proxy: {}), :using_authenticated_proxy?
  end

  def test_using_authenticated_proxy_with_two_keys_returns_false
    refute_predicate build_request(proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }),
                     :using_authenticated_proxy?
  end

  def test_using_authenticated_proxy_with_three_keys_returns_false
    proxy = { proxy_address: "proxy.example.com", proxy_port: 8080, proxy_username: "user" }

    refute_predicate build_request(proxy: proxy), :using_authenticated_proxy?
  end

  def test_using_authenticated_proxy_with_four_keys_returns_true
    proxy = { proxy_address: "proxy.example.com", proxy_port: 8080,
              proxy_username: "user", proxy_password: "pass" }

    assert_predicate build_request(proxy: proxy), :using_authenticated_proxy?
  end

  # #redirect

  def test_redirect_has_correct_uri
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/")

    assert_equal HTTP::URI.parse("http://blog.example.com/"), redirected.uri
  end

  def test_redirect_has_correct_verb
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/")

    assert_equal request.verb, redirected.verb
  end

  def test_redirect_has_correct_body
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/")

    assert_equal request.body, redirected.body
  end

  def test_redirect_has_correct_proxy
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/")

    assert_equal request.proxy, redirected.proxy
  end

  def test_redirect_presets_new_host_header
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/")

    assert_equal "blog.example.com", redirected.headers["Host"]
  end

  def test_redirect_preserves_version
    req = HTTP::Request.new(
      verb: :post, uri: "http://example.com/", body: "The Ultimate Question", version: "2.0"
    )
    redir = req.redirect("http://blog.example.com/")

    assert_equal "2.0", redir.version
  end

  def test_redirect_preserves_uri_normalizer
    custom = ->(uri) { HTTP::URI.parse(uri) }
    req = HTTP::Request.new(
      verb: :post, uri: "http://example.com/", body: "The Ultimate Question", uri_normalizer: custom
    )
    redir = req.redirect("http://blog.example.com/")

    assert_equal custom, redir.uri_normalizer
  end

  def test_redirect_preserves_accept_header
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/")

    assert_equal "text/html", redirected.headers["Accept"]
  end

  # redirect with non-standard port

  def test_redirect_with_non_standard_port_has_correct_uri
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://example.com:8080")

    assert_equal HTTP::URI.parse("http://example.com:8080"), redirected.uri
  end

  def test_redirect_with_non_standard_port_has_correct_verb
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://example.com:8080")

    assert_equal request.verb, redirected.verb
  end

  def test_redirect_with_non_standard_port_has_correct_body
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://example.com:8080")

    assert_equal request.body, redirected.body
  end

  def test_redirect_with_non_standard_port_has_correct_proxy
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://example.com:8080")

    assert_equal request.proxy, redirected.proxy
  end

  def test_redirect_with_non_standard_port_presets_new_host_header
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://example.com:8080")

    assert_equal "example.com:8080", redirected.headers["Host"]
  end

  # redirect with schema-less absolute URL

  def test_redirect_with_schema_less_absolute_url_has_correct_uri
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("//another.example.com/blog")

    assert_equal HTTP::URI.parse("http://another.example.com/blog"), redirected.uri
  end

  def test_redirect_with_schema_less_absolute_url_has_correct_verb
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("//another.example.com/blog")

    assert_equal request.verb, redirected.verb
  end

  def test_redirect_with_schema_less_absolute_url_has_correct_body
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("//another.example.com/blog")

    assert_equal request.body, redirected.body
  end

  def test_redirect_with_schema_less_absolute_url_has_correct_proxy
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("//another.example.com/blog")

    assert_equal request.proxy, redirected.proxy
  end

  def test_redirect_with_schema_less_absolute_url_presets_new_host_header
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("//another.example.com/blog")

    assert_equal "another.example.com", redirected.headers["Host"]
  end

  # redirect with relative URL

  def test_redirect_with_relative_url_has_correct_uri
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("/blog")

    assert_equal HTTP::URI.parse("http://example.com/blog"), redirected.uri
  end

  def test_redirect_with_relative_url_has_correct_verb
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("/blog")

    assert_equal request.verb, redirected.verb
  end

  def test_redirect_with_relative_url_has_correct_body
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("/blog")

    assert_equal request.body, redirected.body
  end

  def test_redirect_with_relative_url_has_correct_proxy
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("/blog")

    assert_equal request.proxy, redirected.proxy
  end

  def test_redirect_with_relative_url_keeps_host_header
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("/blog")

    assert_equal "example.com", redirected.headers["Host"]
  end

  def test_redirect_with_relative_url_and_non_standard_port_has_correct_uri
    request = HTTP::Request.new(
      verb: :post, uri: "http://example.com:8080/",
      headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" },
      body: "The Ultimate Question"
    )
    redirected = request.redirect("/blog")

    assert_equal HTTP::URI.parse("http://example.com:8080/blog"), redirected.uri
  end

  # redirect with relative URL missing leading slash

  def test_redirect_with_relative_url_missing_leading_slash_has_correct_uri
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("blog")

    assert_equal HTTP::URI.parse("http://example.com/blog"), redirected.uri
  end

  def test_redirect_with_relative_url_missing_leading_slash_has_correct_verb
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("blog")

    assert_equal request.verb, redirected.verb
  end

  def test_redirect_with_relative_url_missing_leading_slash_has_correct_body
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("blog")

    assert_equal request.body, redirected.body
  end

  def test_redirect_with_relative_url_missing_leading_slash_has_correct_proxy
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("blog")

    assert_equal request.proxy, redirected.proxy
  end

  def test_redirect_with_relative_url_missing_leading_slash_keeps_host_header
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("blog")

    assert_equal "example.com", redirected.headers["Host"]
  end

  def test_redirect_with_relative_url_missing_leading_slash_and_non_standard_port
    request = HTTP::Request.new(
      verb: :post, uri: "http://example.com:8080/",
      headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" },
      body: "The Ultimate Question"
    )
    redirected = request.redirect("blog")

    assert_equal HTTP::URI.parse("http://example.com:8080/blog"), redirected.uri
  end

  # redirect with new verb

  def test_redirect_with_new_verb_has_correct_verb
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/", :get)

    assert_equal :get, redirected.verb
  end

  def test_redirect_with_new_verb_sets_body_to_nil_for_get_redirect
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://blog.example.com/", :get)

    assert_nil redirected.body.source
  end

  def test_redirect_with_verb_changed_to_non_get_preserves_body
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redir = request.redirect("http://blog.example.com/", :put)

    assert_equal "The Ultimate Question", redir.body.source
  end

  # redirect with sensitive headers - same origin

  def test_redirect_same_origin_preserves_authorization_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("/other-path")

    assert_equal "Bearer token123", redirected.headers["Authorization"]
  end

  def test_redirect_same_origin_preserves_cookie_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("/other-path")

    assert_equal "session=abc", redirected.headers["Cookie"]
  end

  # redirect with sensitive headers - different host

  def test_redirect_different_host_strips_authorization_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://other.example.com/")

    assert_nil redirected.headers["Authorization"]
  end

  def test_redirect_different_host_strips_cookie_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://other.example.com/")

    assert_nil redirected.headers["Cookie"]
  end

  # redirect with sensitive headers - different scheme

  def test_redirect_different_scheme_strips_authorization_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("https://example.com/")

    assert_nil redirected.headers["Authorization"]
  end

  def test_redirect_different_scheme_strips_cookie_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("https://example.com/")

    assert_nil redirected.headers["Cookie"]
  end

  # redirect with sensitive headers - different port

  def test_redirect_different_port_strips_authorization_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://example.com:8080/")

    assert_nil redirected.headers["Authorization"]
  end

  def test_redirect_different_port_strips_cookie_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("http://example.com:8080/")

    assert_nil redirected.headers["Cookie"]
  end

  # redirect with sensitive headers - schema-less URL with different host

  def test_redirect_schema_less_different_host_strips_authorization_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("//other.example.com/path")

    assert_nil redirected.headers["Authorization"]
  end

  def test_redirect_schema_less_different_host_strips_cookie_header
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redirected = request.redirect("//other.example.com/path")

    assert_nil redirected.headers["Cookie"]
  end

  # redirect with Content-Type header

  def test_redirect_post_preserves_content_type
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", content_type: "application/json" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redir = request.redirect("http://blog.example.com/")

    assert_equal "application/json", redir.headers["Content-Type"]
  end

  def test_redirect_to_get_strips_content_type
    request = build_request(
      verb: :post, uri: "http://example.com/",
      headers: { accept: "text/html", content_type: "application/json" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redir = request.redirect("http://blog.example.com/", :get)

    assert_nil redir.headers["Content-Type"]
  end

  def test_redirect_always_strips_host_header_before_redirect
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redir = request.redirect("/other-path")

    assert_equal "example.com", redir.headers["Host"]
  end

  def test_redirect_does_not_mutate_original_request_headers
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    original_accept = request.headers["Accept"]
    request.redirect("http://other.example.com/", :get)

    assert_equal original_accept, request.headers["Accept"]
    assert_equal "example.com", request.headers["Host"]
  end

  def test_redirect_preserves_body_source_on_non_get_redirect
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redir = request.redirect("http://blog.example.com/")

    assert_equal "The Ultimate Question", redir.body.source
  end

  def test_redirect_creates_a_new_body_object
    request = build_request(
      verb: :post, uri: "http://example.com/", headers: { accept: "text/html" },
      proxy: { proxy_username: "douglas", proxy_password: "adams" }, body: "The Ultimate Question"
    )
    redir = request.redirect("http://blog.example.com/")

    refute_same request.body, redir.body
  end

  # #headline

  def test_headline_returns_the_request_line
    assert_equal "GET /foo?bar=baz HTTP/1.1", build_request.headline
  end

  def test_headline_with_encoded_query_does_not_unencode_query_part
    encoded_query = "t=1970-01-01T01%3A00%3A00%2B01%3A00"
    request = build_request(uri: "http://example.com/foo/?#{encoded_query}")

    assert_equal "GET /foo/?#{encoded_query} HTTP/1.1", request.headline
  end

  def test_headline_with_non_ascii_path_encodes_non_ascii_part
    request = build_request(uri: "http://example.com/\u30AD\u30E7")

    assert_equal "GET /%E3%82%AD%E3%83%A7 HTTP/1.1", request.headline
  end

  def test_headline_with_fragment_omits_fragment_part
    request = build_request(uri: "http://example.com/foo#bar")

    assert_equal "GET /foo HTTP/1.1", request.headline
  end

  def test_headline_with_proxy_uses_absolute_uri_in_request_line
    request = build_request(proxy: { user: "user", pass: "pass" })

    assert_equal "GET http://example.com/foo?bar=baz HTTP/1.1", request.headline
  end

  def test_headline_with_proxy_and_fragment_omits_fragment
    request = build_request(uri: "http://example.com/foo#bar", proxy: { user: "user", pass: "pass" })

    assert_equal "GET http://example.com/foo HTTP/1.1", request.headline
  end

  def test_headline_with_proxy_and_https_uses_relative_uri
    request = build_request(uri: "https://example.com/foo?bar=baz", proxy: { user: "user", pass: "pass" })

    assert_equal "GET /foo?bar=baz HTTP/1.1", request.headline
  end

  def test_headline_with_custom_version_includes_version
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/", version: "2.0")

    assert_equal "GET / HTTP/2.0", req.headline
  end

  def test_headline_with_non_get_verb_upcases_the_verb
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/")

    assert_equal "POST / HTTP/1.1", req.headline
  end

  def test_headline_with_uri_containing_whitespace_raises_request_error
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/foo")
    req.uri.path = "/foo bar"

    err = assert_raises(HTTP::RequestError) { req.headline }

    assert_includes err.message, "Invalid request URI"
    assert_includes err.message, "/foo bar".inspect
  end

  # #socket_host

  def test_socket_host_without_proxy_returns_uri_host
    assert_equal "example.com", build_request(proxy: {}).socket_host
  end

  def test_socket_host_with_proxy_returns_proxy_address
    request = build_request(proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 })

    assert_equal "proxy.example.com", request.socket_host
  end

  # #socket_port

  def test_socket_port_without_proxy_returns_uri_port
    assert_equal 80, build_request(proxy: {}).socket_port
  end

  def test_socket_port_without_proxy_with_explicit_port_returns_explicit_port
    request = build_request(uri: "http://example.com:3000/", proxy: {})

    assert_equal 3000, request.socket_port
  end

  def test_socket_port_without_proxy_with_https_returns_443
    request = build_request(uri: "https://example.com/", proxy: {})

    assert_equal 443, request.socket_port
  end

  def test_socket_port_with_proxy_returns_proxy_port
    request = build_request(proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 })

    assert_equal 8080, request.socket_port
  end

  # #stream

  def test_stream_without_proxy_writes_request_to_socket
    io = StringIO.new
    build_request(proxy: {}).stream(io)

    assert_includes io.string, "GET /foo?bar=baz HTTP/1.1"
  end

  def test_stream_without_proxy_does_not_include_proxy_headers
    io = StringIO.new
    build_request(proxy: {}).stream(io)

    refute_includes io.string, "Proxy-Authorization"
  end

  def test_stream_with_proxy_headers_but_not_using_proxy_does_not_include_them
    io = StringIO.new
    build_request(proxy: { proxy_headers: { "X-Leak" => "nope" } }).stream(io)

    refute_includes io.string, "X-Leak"
  end

  def test_stream_with_http_proxy_merges_proxy_headers
    io = StringIO.new
    request = build_request(proxy: {
      proxy_address: "proxy.example.com",
      proxy_port:    8080,
      proxy_headers: { "X-Proxy" => "value" }
    })
    request.stream(io)

    assert_includes io.string, "X-Proxy: value"
  end

  def test_stream_with_https_proxy_and_proxy_headers_does_not_merge
    io = StringIO.new
    request = build_request(
      uri:   "https://example.com/foo",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass",
        proxy_headers:  { "X-Proxy" => "nope" }
      }
    )
    request.stream(io)
    output = io.string

    refute_includes output, "X-Proxy"
    refute_includes output, "Proxy-Authorization"
  end

  def test_stream_with_authenticated_http_proxy_includes_proxy_authorization
    io = StringIO.new
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })
    request.stream(io)

    assert_includes io.string, "Proxy-Authorization: Basic"
  end

  # #connect_using_proxy

  def test_connect_using_proxy_writes_a_connect_request
    io = StringIO.new
    request = build_request(
      uri:   "https://example.com/foo",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    request.connect_using_proxy(io)
    output = io.string

    assert_includes output, "CONNECT example.com:443 HTTP/1.1"
  end

  def test_connect_using_proxy_includes_proxy_auth_headers
    io = StringIO.new
    request = build_request(
      uri:   "https://example.com/foo",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    request.connect_using_proxy(io)
    output = io.string

    assert_includes output, "Proxy-Authorization: Basic"
  end

  def test_connect_using_proxy_includes_host_header
    io = StringIO.new
    request = build_request(
      uri:   "https://example.com/foo",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    request.connect_using_proxy(io)
    output = io.string

    assert_includes output, "Host: example.com"
  end

  def test_connect_using_proxy_includes_user_agent_header
    io = StringIO.new
    request = build_request(
      uri:   "https://example.com/foo",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    request.connect_using_proxy(io)
    output = io.string

    assert_includes output, "User-Agent:"
  end

  # #proxy_connect_header

  def test_proxy_connect_header_returns_connect_headline
    request = build_request(uri: "https://example.com/")

    assert_equal "CONNECT example.com:443 HTTP/1.1", request.proxy_connect_header
  end

  def test_proxy_connect_header_with_non_standard_port_includes_the_port
    request = build_request(uri: "https://example.com:8443/")

    assert_equal "CONNECT example.com:8443 HTTP/1.1", request.proxy_connect_header
  end

  def test_proxy_connect_header_with_custom_version_includes_the_version
    req = HTTP::Request.new(verb: :get, uri: "https://example.com/", version: "2.0")

    assert_equal "CONNECT example.com:443 HTTP/2.0", req.proxy_connect_header
  end

  # #proxy_connect_headers

  def test_proxy_connect_headers_with_authenticated_proxy_includes_proxy_authorization
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    hdrs = request.proxy_connect_headers

    assert_match(/^Basic /, hdrs["Proxy-Authorization"])
  end

  def test_proxy_connect_headers_with_authenticated_proxy_includes_host_header
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    hdrs = request.proxy_connect_headers

    assert_equal "example.com", hdrs["Host"]
  end

  def test_proxy_connect_headers_with_authenticated_proxy_includes_user_agent
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    hdrs = request.proxy_connect_headers

    assert_equal HTTP::Request::USER_AGENT, hdrs["User-Agent"]
  end

  def test_proxy_connect_headers_with_unauthenticated_proxy_no_proxy_authorization
    request = build_request(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    hdrs = request.proxy_connect_headers

    assert_nil hdrs["Proxy-Authorization"]
  end

  def test_proxy_connect_headers_with_unauthenticated_proxy_includes_host
    request = build_request(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    hdrs = request.proxy_connect_headers

    assert_equal "example.com", hdrs["Host"]
  end

  def test_proxy_connect_headers_with_unauthenticated_proxy_includes_user_agent
    request = build_request(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    hdrs = request.proxy_connect_headers

    assert_equal HTTP::Request::USER_AGENT, hdrs["User-Agent"]
  end

  def test_proxy_connect_headers_with_proxy_headers_includes_custom_headers
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address: "proxy.example.com",
        proxy_port:    8080,
        proxy_headers: { "X-Custom" => "value" }
      }
    )
    hdrs = request.proxy_connect_headers

    assert_equal "value", hdrs["X-Custom"]
  end

  def test_proxy_connect_headers_without_proxy_headers_key_only_includes_host_and_user_agent
    request = build_request(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    hdrs = request.proxy_connect_headers

    assert_instance_of HTTP::Headers, hdrs
    assert_equal %w[Host User-Agent], hdrs.keys
  end

  # #include_proxy_headers

  def test_include_proxy_headers_with_proxy_headers_and_authenticated_proxy_merges
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass",
      proxy_headers:  { "X-Proxy" => "value" }
    })
    request.include_proxy_headers

    assert_equal "value", request.headers["X-Proxy"]
  end

  def test_include_proxy_headers_with_proxy_headers_and_authenticated_proxy_adds_auth
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass",
      proxy_headers:  { "X-Proxy" => "value" }
    })
    request.include_proxy_headers

    assert_match(/^Basic /, request.headers["Proxy-Authorization"])
  end

  def test_include_proxy_headers_with_proxy_headers_but_unauthenticated_merges
    request = build_request(proxy: {
      proxy_address: "proxy.example.com",
      proxy_port:    8080,
      proxy_headers: { "X-Proxy" => "value" }
    })
    request.include_proxy_headers

    assert_equal "value", request.headers["X-Proxy"]
  end

  def test_include_proxy_headers_with_proxy_headers_but_unauthenticated_no_auth
    request = build_request(proxy: {
      proxy_address: "proxy.example.com",
      proxy_port:    8080,
      proxy_headers: { "X-Proxy" => "value" }
    })
    request.include_proxy_headers

    assert_nil request.headers["Proxy-Authorization"]
  end

  def test_include_proxy_headers_without_proxy_headers_key_still_adds_auth
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })
    request.include_proxy_headers

    assert_match(/^Basic /, request.headers["Proxy-Authorization"])
  end

  def test_include_proxy_headers_without_proxy_headers_key_does_not_raise
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })
    headers_before = request.headers.to_h.except("Proxy-Authorization")
    request.include_proxy_headers
    headers_after = request.headers.to_h.except("Proxy-Authorization")

    assert_equal headers_before, headers_after
  end

  # #include_proxy_authorization_header

  def test_include_proxy_authorization_header_sets_header
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })
    request.include_proxy_authorization_header

    assert_equal request.proxy_authorization_header, request.headers["Proxy-Authorization"]
  end

  # #proxy_authorization_header

  def test_proxy_authorization_header_returns_basic_auth_header
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })

    assert request.proxy_authorization_header.start_with?("Basic ")
  end

  def test_proxy_authorization_header_encodes_username_and_password
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })
    expected_digest = ["user:pass"].pack("m0")

    assert_equal "Basic #{expected_digest}", request.proxy_authorization_header
  end

  # #inspect

  def test_inspect_returns_a_useful_string_representation
    request_uri = "http://example.com/foo?bar=baz"

    assert_equal "#<HTTP::Request/1.1 GET #{request_uri}>", build_request(uri: request_uri).inspect
  end

  def test_inspect_includes_the_class_name
    assert_includes build_request.inspect, "HTTP::Request"
  end

  def test_inspect_includes_the_version
    assert_includes build_request.inspect, "1.1"
  end

  def test_inspect_includes_the_uppercased_verb
    assert_includes build_request.inspect, "GET"
  end

  def test_inspect_includes_the_uri
    request_uri = "http://example.com/foo?bar=baz"

    assert_includes build_request(uri: request_uri).inspect, request_uri
  end

  def test_inspect_with_post_verb_shows_post
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/")

    assert_includes req.inspect, "POST"
  end

  def test_inspect_works_when_verb_is_a_symbol
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

    assert_includes req.inspect, "GET"
    assert_equal "#<HTTP::Request/1.1 GET http://example.com/>", req.inspect
  end

  # #port (private)

  def test_port_returns_the_default_port_when_uri_has_no_explicit_port
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

    assert_equal 80, req.socket_port
  end

  def test_port_returns_the_explicit_port_when_uri_specifies_one
    req = HTTP::Request.new(verb: :get, uri: "http://example.com:9292/")

    assert_equal 9292, req.socket_port
  end

  def test_port_returns_https_default_port
    req = HTTP::Request.new(verb: :get, uri: "https://example.com/")

    assert_equal 443, req.socket_port
  end

  def test_port_returns_ws_default_port
    req = HTTP::Request.new(verb: :get, uri: "ws://example.com/")

    assert_equal 80, req.socket_port
  end

  def test_port_returns_wss_default_port
    req = HTTP::Request.new(verb: :get, uri: "wss://example.com/")

    assert_equal 443, req.socket_port
  end

  # #default_host_header_value (private)

  def test_default_host_header_value_omits_port_for_standard_http
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

    assert_equal "example.com", req.headers["Host"]
  end

  def test_default_host_header_value_omits_port_for_standard_ws
    req = HTTP::Request.new(verb: :get, uri: "ws://example.com/")

    assert_equal "example.com", req.headers["Host"]
  end

  def test_default_host_header_value_omits_port_for_standard_wss
    req = HTTP::Request.new(verb: :get, uri: "wss://example.com/")

    assert_equal "example.com", req.headers["Host"]
  end

  def test_default_host_header_value_includes_port_for_non_standard_ws
    req = HTTP::Request.new(verb: :get, uri: "ws://example.com:8080/")

    assert_equal "example.com:8080", req.headers["Host"]
  end

  # #parse_uri! (private)

  def test_parse_uri_raises_argument_error_for_empty_string_subclass
    string_subclass = Class.new(String)
    err = assert_raises(ArgumentError) do
      HTTP::Request.new(verb: :get, uri: string_subclass.new(""))
    end
    assert_equal "uri is empty", err.message
  end

  def test_parse_uri_normalizes_uppercase_scheme_to_lowercase_symbol
    req = HTTP::Request.new(verb: :get, uri: "HTTP://example.com/")

    assert_equal :http, req.scheme
  end

  def test_parse_uri_normalizes_mixed_case_scheme
    req = HTTP::Request.new(verb: :get, uri: "HtTpS://example.com/")

    assert_equal :https, req.scheme
  end

  # #prepare_headers (private)

  def test_prepare_headers_sets_default_host_and_user_agent_when_headers_nil
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

    assert_equal "example.com", req.headers["Host"]
    assert_equal HTTP::Request::USER_AGENT, req.headers["User-Agent"]
  end

  # #prepare_body (private)

  def test_prepare_body_wraps_a_string_body_in_request_body
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "test")

    assert_instance_of HTTP::Request::Body, req.body
    assert_equal "test", req.body.source
  end

  # #validate_method_and_scheme! (private)

  def test_validate_method_and_scheme_raises_http_uri_invalid_error_for_missing_scheme
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::Request.new(verb: :get, uri: "example.com/")
    end
    assert_kind_of HTTP::URI::InvalidError, err
  end

  # #redirect (additional mutation killing tests)

  def test_redirect_post_to_get_sets_body_source_to_nil
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "data")
    redir = req.redirect("http://other.com/", :get)

    assert_nil redir.body.source
  end

  def test_redirect_post_to_post_preserves_body_source
    req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "data")
    redir = req.redirect("http://other.com/", :post)

    assert_equal "data", redir.body.source
  end

  # #redirect_headers (private)

  def test_redirect_headers_include_original_non_stripped_headers
    req = HTTP::Request.new(
      verb:    :post,
      uri:     "http://example.com/",
      headers: { accept: "text/html", "X-Custom" => "val" }
    )
    redir = req.redirect("/other")

    assert_equal "text/html", redir.headers["Accept"]
    assert_equal "val", redir.headers["X-Custom"]
  end

  # #headline (additional mutation killing tests)

  def test_headline_returns_a_string
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/path")
    headline = req.headline

    assert_instance_of String, headline
    assert_equal "GET /path HTTP/1.1", headline
  end

  def test_headline_converts_symbol_verb_to_uppercase_string
    req = HTTP::Request.new(verb: :delete, uri: "http://example.com/")

    assert_equal "DELETE / HTTP/1.1", req.headline
  end

  # #initialize (additional mutation killing tests)

  def test_initialize_uses_http_uri_normalizer_by_default
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

    assert_equal HTTP::URI::NORMALIZER, req.uri_normalizer
  end

  def test_initialize_converts_string_verb_via_to_s_before_downcase
    req = HTTP::Request.new(verb: "GET", uri: "http://example.com/")

    assert_equal :get, req.verb
  end

  # #stream (additional mutation killing tests)

  def test_stream_creates_a_writer_and_streams_to_socket
    io = StringIO.new
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/path")
    req.stream(io)

    assert_match(%r{^GET /path HTTP/1\.1\r\n}, io.string)
    assert_includes io.string, "Host: example.com"
  end

  # #socket_host (additional mutation killing tests)

  def test_socket_host_with_proxy_that_has_proxy_address_returns_value
    request = build_request(proxy: { proxy_address: "myproxy.com", proxy_port: 3128 })

    assert_equal "myproxy.com", request.socket_host
  end

  # #socket_port (additional mutation killing tests)

  def test_socket_port_with_proxy_that_has_proxy_port_returns_value
    request = build_request(proxy: { proxy_address: "myproxy.com", proxy_port: 3128 })

    assert_equal 3128, request.socket_port
  end

  # #using_proxy? (additional mutation killing tests)

  def test_using_proxy_with_nil_proxy_returns_false
    req = HTTP::Request.new(verb: :get, uri: "http://example.com/", proxy: {})

    refute_predicate req, :using_proxy?
  end

  def test_using_proxy_with_exactly_two_keys_returns_true
    request = build_request(proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 })

    assert_predicate request, :using_proxy?
  end

  def test_using_proxy_with_three_keys_returns_true
    request = build_request(proxy: { proxy_address: "proxy.example.com", proxy_port: 8080, extra: "x" })

    assert_predicate request, :using_proxy?
  end

  # #using_authenticated_proxy? (additional mutation killing tests)

  def test_using_authenticated_proxy_with_exactly_four_keys_returns_true
    proxy = { proxy_address: "proxy.example.com", proxy_port: 8080,
              proxy_username: "user", proxy_password: "pass" }
    request = build_request(proxy: proxy)

    assert_predicate request, :using_authenticated_proxy?
  end

  def test_using_authenticated_proxy_with_five_keys_returns_true
    proxy = { proxy_address: "proxy.example.com", proxy_port: 8080,
              proxy_username: "user", proxy_password: "pass", extra: "x" }
    request = build_request(proxy: proxy)

    assert_predicate request, :using_authenticated_proxy?
  end

  # #include_proxy_headers (additional mutation killing tests)

  def test_include_proxy_headers_authenticated_no_proxy_headers_key_does_not_merge_nil
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })
    header_count_before = request.headers.to_h.except("Proxy-Authorization").size
    request.include_proxy_headers
    header_count_after = request.headers.to_h.except("Proxy-Authorization").size

    assert_equal header_count_before, header_count_after
  end

  def test_include_proxy_headers_authenticated_no_proxy_headers_key_does_not_raise
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "user",
      proxy_password: "pass"
    })
    request.include_proxy_headers

    assert_match(/^Basic /, request.headers["Proxy-Authorization"])
  end

  # #proxy_authorization_header (additional mutation killing tests)

  def test_proxy_authorization_header_encodes_correct_username_and_password
    request = build_request(proxy: {
      proxy_address:  "proxy.example.com",
      proxy_port:     8080,
      proxy_username: "alice",
      proxy_password: "secret"
    })
    expected = "Basic #{['alice:secret'].pack('m0')}"

    assert_equal expected, request.proxy_authorization_header
  end

  # #proxy_connect_headers (additional mutation killing tests)

  def test_proxy_connect_headers_authenticated_no_proxy_headers_returns_http_headers
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    hdrs = request.proxy_connect_headers

    assert_instance_of HTTP::Headers, hdrs
  end

  def test_proxy_connect_headers_authenticated_no_proxy_headers_does_not_include_nil
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    hdrs = request.proxy_connect_headers

    assert_equal %w[Host User-Agent Proxy-Authorization], hdrs.keys
  end

  def test_proxy_connect_headers_unauthenticated_with_proxy_headers_includes_custom
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address: "proxy.example.com",
        proxy_port:    8080,
        proxy_headers: { "X-Custom" => "val" }
      }
    )
    hdrs = request.proxy_connect_headers

    assert_equal "val", hdrs["X-Custom"]
  end

  def test_proxy_connect_headers_unauthenticated_with_proxy_headers_includes_host
    request = build_request(
      uri:   "https://example.com/",
      proxy: {
        proxy_address: "proxy.example.com",
        proxy_port:    8080,
        proxy_headers: { "X-Custom" => "val" }
      }
    )
    hdrs = request.proxy_connect_headers

    assert_equal "example.com", hdrs["Host"]
  end

  def test_proxy_connect_headers_unauthenticated_no_proxy_headers_does_not_raise
    request = build_request(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    hdrs = request.proxy_connect_headers

    assert_instance_of HTTP::Headers, hdrs
    assert_equal %w[Host User-Agent], hdrs.keys
  end

  # #connect_using_proxy (additional mutation killing tests)

  def test_connect_using_proxy_writes_valid_connect_request_line
    io = StringIO.new
    request = build_request(
      uri:   "https://example.com:8443/foo",
      proxy: {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    )
    request.connect_using_proxy(io)

    assert_match(%r{^CONNECT example\.com:8443 HTTP/1\.1\r\n}, io.string)
  end
end
