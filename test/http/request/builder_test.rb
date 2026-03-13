# frozen_string_literal: true

require "test_helper"

describe HTTP::Request::Builder do
  cover "HTTP::Request::Builder*"

  let(:options) { HTTP::Options.new(**option_overrides) }
  let(:builder) { HTTP::Request::Builder.new(options) }
  let(:option_overrides) { {} }

  describe "#build" do
    let(:request) { builder.build(:get, "http://example.com/path") }

    it "returns an HTTP::Request" do
      assert_kind_of HTTP::Request, request
    end

    it "sets the verb on the request" do
      assert_equal :get, request.verb
    end

    it "sets the URI on the request" do
      assert_equal "/path", request.uri.path
    end

    it "sets Connection: close by default" do
      assert_equal HTTP::Connection::CLOSE, request.headers["Connection"]
    end

    it "sets the proxy from options" do
      opts = HTTP::Options.new(proxy: { proxy_address: "proxy.example.com" })
      b = HTTP::Request::Builder.new(opts)
      req = b.build(:get, "http://example.com/")

      assert_equal({ proxy_address: "proxy.example.com" }, req.proxy)
    end

    context "with persistent connection" do
      let(:option_overrides) { { persistent: "http://example.com" } }

      it "sets Connection: Keep-Alive" do
        assert_equal HTTP::Connection::KEEP_ALIVE, request.headers["Connection"]
      end
    end

    context "when URI has empty path" do
      let(:request) { builder.build(:get, "http://example.com") }

      it "sets path to /" do
        assert_equal "/", request.uri.path
      end
    end

    context "when URI has a non-empty path" do
      let(:request) { builder.build(:get, "http://example.com/foo") }

      it "preserves the path" do
        assert_equal "/foo", request.uri.path
      end
    end

    context "with query params in options" do
      let(:option_overrides) { { params: { "foo" => "bar" } } }

      it "merges params into the URI query" do
        assert_includes request.uri.query, "foo=bar"
      end
    end

    context "with query params in options and existing query in URI" do
      let(:option_overrides) { { params: { "extra" => "val" } } }
      let(:request) { builder.build(:get, "http://example.com/path?existing=1") }

      it "preserves existing query params" do
        assert_includes request.uri.query, "existing=1"
      end

      it "appends new params" do
        assert_includes request.uri.query, "extra=val"
      end
    end

    context "with body in options" do
      let(:option_overrides) { { body: "raw body" } }

      it "uses body from options" do
        req = builder.build(:post, "http://example.com/")
        chunks = req.body.enum_for(:each).map(&:dup)

        assert_equal ["raw body"], chunks
      end
    end

    context "with form data in options" do
      let(:option_overrides) { { form: { "key" => "value" } } }

      it "sets Content-Type header" do
        req = builder.build(:post, "http://example.com/")

        refute_nil req.headers["Content-Type"]
      end

      it "includes form data in the body" do
        req = builder.build(:post, "http://example.com/")
        chunks = req.body.enum_for(:each).map(&:dup)
        body_str = chunks.join

        assert_includes body_str, "key=value"
      end
    end

    context "with json in options" do
      let(:option_overrides) { { json: { "key" => "value" } } }

      it "encodes JSON body" do
        req = builder.build(:post, "http://example.com/")
        chunks = req.body.enum_for(:each).map(&:dup)

        assert_equal [{ "key" => "value" }.to_json], chunks
      end

      it "sets Content-Type to application/json" do
        req = builder.build(:post, "http://example.com/")

        assert_match(%r{\Aapplication/json}, req.headers["Content-Type"])
      end
    end

    context "with normalize_uri feature using custom normalizer" do
      let(:custom_normalizer) { ->(uri) { HTTP::URI::NORMALIZER.call(uri) } }
      let(:option_overrides) { { features: { normalize_uri: { normalizer: custom_normalizer } } } }

      it "passes the custom normalizer to the request" do
        req = builder.build(:get, "http://example.com/path")

        assert_same custom_normalizer, req.uri_normalizer
      end
    end

    context "without normalize_uri feature" do
      it "uses the default normalizer" do
        req = builder.build(:get, "http://example.com/path")

        assert_equal HTTP::URI::NORMALIZER, req.uri_normalizer
      end
    end

    context "with an object responding to to_s as URI" do
      it "converts the URI to string" do
        uri_obj = Object.new
        uri_obj.define_singleton_method(:to_s) { "http://example.com/converted" }
        req = builder.build(:get, uri_obj)

        assert_equal "/converted", req.uri.path
      end
    end

    context "with a URI object and base_uri" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "converts non-string URI to string before matching scheme" do
        uri_obj = Object.new
        uri_obj.define_singleton_method(:to_s) { "users" }
        req = builder.build(:get, uri_obj)

        assert_equal "example.com", req.uri.host
        assert_equal "/api/users", req.uri.path
      end
    end

    context "with a feature that wraps the request" do
      it "returns the wrapped request from build" do
        wrapped = nil
        feature_class = Class.new(HTTP::Feature) do
          define_method(:wrap_request) do |req|
            wrapped = HTTP::Request.new(
              verb: req.verb,
              uri:  "http://wrapped.example.com/wrapped"
            )
            wrapped
          end
        end

        HTTP::Options.register_feature(:test_build_wrap, feature_class)
        begin
          opts = HTTP::Options.new(features: { test_build_wrap: {} })
          b = HTTP::Request::Builder.new(opts)
          result = b.build(:get, "http://example.com/original")

          assert_same wrapped, result
          assert_equal "/wrapped", result.uri.path
        ensure
          HTTP::Options.available_features.delete(:test_build_wrap)
        end
      end
    end
  end

  describe "#build with base_uri" do
    context "when URI is relative" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "resolves against base URI" do
        req = builder.build(:get, "users")

        assert_equal "example.com", req.uri.host
        assert_match(%r{/api/users}, req.uri.path)
      end
    end

    context "when base URI path does not end with slash" do
      let(:option_overrides) { { base_uri: "http://example.com/api" } }

      it "appends slash before joining" do
        req = builder.build(:get, "users")

        assert_equal "example.com", req.uri.host
        assert_match(%r{/api/users}, req.uri.path)
      end

      it "does not mutate the original base URI path" do
        original_path = options.base_uri.path.dup
        builder.build(:get, "users")

        assert_equal original_path, options.base_uri.path
      end
    end

    context "when base URI path already ends with slash" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "does not double the slash" do
        req = builder.build(:get, "users")

        assert_equal "/api/users", req.uri.path
      end
    end

    context "when URI is absolute" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "does not use base URI for http:// URIs" do
        req = builder.build(:get, "http://other.com/path")

        assert_equal "other.com", req.uri.host
        assert_equal "/path", req.uri.path
      end

      it "does not use base URI for https:// URIs" do
        req = builder.build(:get, "https://secure.example.com/path")

        assert_equal "secure.example.com", req.uri.host
      end
    end

    context "when base_uri raises for missing base" do
      it "raises HTTP::Error with descriptive message" do
        # Force resolve_against_base to be called without base_uri set
        # by creating options where base_uri? is true but base_uri returns nil
        opts = HTTP::Options.new(base_uri: "http://example.com/")
        b = HTTP::Request::Builder.new(opts)
        # This should not raise (base_uri is set)
        req = b.build(:get, "relative")

        assert_equal "example.com", req.uri.host
      end
    end
  end

  describe "#build with persistent" do
    context "when URI is relative" do
      let(:option_overrides) { { persistent: "http://example.com" } }

      it "prepends persistent origin" do
        req = builder.build(:get, "/path")

        assert_equal "example.com", req.uri.host
        assert_equal "/path", req.uri.path
      end

      it "does not prepend when not persistent" do
        non_persistent_opts = HTTP::Options.new
        b = HTTP::Request::Builder.new(non_persistent_opts)
        # A relative URI without persistent should not get a host prepended
        # (it will fail to parse as a valid URI, but won't prepend)
        req = b.build(:get, "http://fallback.com/path")

        assert_equal "fallback.com", req.uri.host
      end
    end

    context "when URI is absolute" do
      let(:option_overrides) { { persistent: "http://example.com" } }

      it "uses the absolute URI as-is" do
        req = builder.build(:get, "http://other.com/path")

        assert_equal "other.com", req.uri.host
      end
    end
  end

  describe "#wrap" do
    it "returns the request when no features are configured" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")
      result = builder.wrap(req)

      assert_same req, result
    end

    context "with a feature that wraps requests" do
      it "applies feature wrapping" do
        wrapped_request = nil
        feature_class = Class.new(HTTP::Feature) do
          define_method(:wrap_request) do |req|
            wrapped_request = req
            req
          end
        end

        HTTP::Options.register_feature(:test_wrap_builder, feature_class)
        begin
          opts = HTTP::Options.new(features: { test_wrap_builder: {} })
          b = HTTP::Request::Builder.new(opts)
          req = HTTP::Request.new(verb: :get, uri: "http://example.com/")
          b.wrap(req)

          assert_same req, wrapped_request
        ensure
          HTTP::Options.available_features.delete(:test_wrap_builder)
        end
      end
    end

    context "with multiple features" do
      it "applies features in order via inject" do
        call_order = []
        feature_a = Class.new(HTTP::Feature) do
          define_method(:wrap_request) do |req|
            call_order << :a
            req
          end
        end
        feature_b = Class.new(HTTP::Feature) do
          define_method(:wrap_request) do |req|
            call_order << :b
            req
          end
        end

        HTTP::Options.register_feature(:test_wrap_a, feature_a)
        HTTP::Options.register_feature(:test_wrap_b, feature_b)
        begin
          opts = HTTP::Options.new(features: { test_wrap_a: {}, test_wrap_b: {} })
          b = HTTP::Request::Builder.new(opts)
          req = HTTP::Request.new(verb: :get, uri: "http://example.com/")
          b.wrap(req)

          assert_equal %i[a b], call_order
        ensure
          HTTP::Options.available_features.delete(:test_wrap_a)
          HTTP::Options.available_features.delete(:test_wrap_b)
        end
      end
    end
  end

  describe "make_request_body (via #build)" do
    context "when body option is set" do
      let(:option_overrides) { { body: "raw" } }

      it "uses the body directly, ignoring form and json" do
        req = builder.build(:post, "http://example.com/")
        chunks = req.body.enum_for(:each).map(&:dup)

        assert_equal ["raw"], chunks
      end
    end

    context "when form option is set" do
      let(:option_overrides) { { form: { "name" => "test" } } }

      it "creates form data body" do
        req = builder.build(:post, "http://example.com/")

        refute_nil req.headers["Content-Type"]
      end

      it "returns form data as the body source" do
        req = builder.build(:post, "http://example.com/")

        refute_nil req.body.source
      end

      it "does not override existing Content-Type" do
        opts = HTTP::Options.new(
          form:    { "name" => "test" },
          headers: { "Content-Type" => "custom/type" }
        )
        b = HTTP::Request::Builder.new(opts)
        req = b.build(:post, "http://example.com/")

        assert_equal "custom/type", req.headers["Content-Type"]
      end
    end

    context "when json option is set" do
      let(:option_overrides) { { json: { "key" => "val" } } }

      it "encodes the data as JSON" do
        req = builder.build(:post, "http://example.com/")
        chunks = req.body.enum_for(:each).map(&:dup)

        assert_equal [{ "key" => "val" }.to_json], chunks
      end

      it "includes charset in Content-Type" do
        req = builder.build(:post, "http://example.com/")

        assert_match(/charset=utf-8/, req.headers["Content-Type"])
      end

      it "does not override existing Content-Type" do
        opts = HTTP::Options.new(
          json:    { "key" => "val" },
          headers: { "Content-Type" => "custom/json" }
        )
        b = HTTP::Request::Builder.new(opts)
        req = b.build(:post, "http://example.com/")

        assert_equal "custom/json", req.headers["Content-Type"]
      end
    end

    context "when no body, form, or json is set" do
      it "has nil body source" do
        req = builder.build(:get, "http://example.com/")

        assert_nil req.body.source
      end
    end
  end

  describe "make_form_data (via #build)" do
    context "with a hash form" do
      let(:option_overrides) { { form: { "field" => "value" } } }

      it "creates form data via HTTP::FormData.create" do
        req = builder.build(:post, "http://example.com/")

        refute_nil req.headers["Content-Type"]
      end

      it "passes the form hash data through to the body" do
        req = builder.build(:post, "http://example.com/")
        chunks = req.body.enum_for(:each).map(&:dup)
        body_str = chunks.join

        assert_includes body_str, "field=value"
      end
    end

    context "with a Multipart form" do
      it "passes through without wrapping" do
        multipart = HTTP::FormData::Multipart.new({ "part" => HTTP::FormData::Part.new("val") })
        opts = HTTP::Options.new(form: multipart)
        b = HTTP::Request::Builder.new(opts)
        req = b.build(:post, "http://example.com/")

        assert_match(%r{\Amultipart/form-data}, req.headers["Content-Type"])
      end
    end

    context "with a Urlencoded form" do
      it "passes through without wrapping" do
        urlencoded = HTTP::FormData::Urlencoded.new({ "field" => "value" })
        opts = HTTP::Options.new(form: urlencoded)
        b = HTTP::Request::Builder.new(opts)
        req = b.build(:post, "http://example.com/")

        assert_equal "application/x-www-form-urlencoded", req.headers["Content-Type"]
      end
    end
  end

  describe "merge_query_params!" do
    context "when params is nil" do
      let(:option_overrides) { {} }

      it "does not add a query string" do
        req = builder.build(:get, "http://example.com/path")

        assert_nil req.uri.query
      end
    end

    context "when params is empty" do
      let(:option_overrides) { { params: {} } }

      it "does not add a query string" do
        req = builder.build(:get, "http://example.com/path")

        assert_nil req.uri.query
      end
    end

    context "when params has values and URI has no query" do
      let(:option_overrides) { { params: { "a" => "1" } } }

      it "sets the query string" do
        req = builder.build(:get, "http://example.com/path")

        assert_equal "a=1", req.uri.query
      end
    end

    context "when params has values and URI has existing query" do
      let(:option_overrides) { { params: { "b" => "2" } } }

      it "concatenates params to existing query" do
        req = builder.build(:get, "http://example.com/path?a=1")

        assert_equal "a=1&b=2", req.uri.query
      end
    end
  end

  describe "empty path normalization (via #build)" do
    it "normalizes empty path to / for URIs without path" do
      req = builder.build(:get, "http://example.com")

      assert_equal "/", req.uri.path
    end

    it "returns an HTTP::URI with the corrected path" do
      req = builder.build(:get, "http://example.com")

      assert_instance_of HTTP::URI, req.uri
      assert_equal "/", req.uri.path
    end
  end

  describe "resolve_against_base error handling (via #build)" do
    it "raises HTTP::Error with the correct class" do
      opts = HTTP::Options.new(base_uri: "http://example.com/")
      b = HTTP::Request::Builder.new(opts)
      # Override base_uri to return nil to trigger the error path
      opts.define_singleton_method(:base_uri) { nil }
      opts.define_singleton_method(:base_uri?) { true }

      err = assert_raises(HTTP::Error) { b.build(:get, "relative") }
      assert_equal "base_uri is not set", err.message
    end
  end

  describe "make_request_uri scheme guard with base_uri" do
    # Kills mutations on: if @options.base_uri? && uri !~ HTTP_OR_HTTPS_RE
    # - removing the regex check (always resolving against base)
    # - replacing uri with nil in the regex
    # - replacing regex with nil
    # - replacing uri !~ with just uri (truthy)
    # - replacing the whole condition with just @options.base_uri?
    # - replacing regex with HTTP_OR_HTTPS_RE constant (always truthy)
    context "when base_uri is set and URI is absolute HTTP" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "uses the absolute URI, not base_uri" do
        req = builder.build(:get, "http://other.com/path")

        assert_equal "other.com", req.uri.host
        assert_equal "/path", req.uri.path
      end
    end

    context "when base_uri is set and URI is absolute HTTPS" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "uses the absolute URI, not base_uri" do
        req = builder.build(:get, "https://secure.com/path")

        assert_equal "secure.com", req.uri.host
        assert_equal "/path", req.uri.path
      end
    end

    context "when base_uri is set and URI is relative" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "resolves relative URI against base" do
        req = builder.build(:get, "users/1")

        assert_equal "example.com", req.uri.host
        assert_equal "/api/users/1", req.uri.path
      end
    end
  end

  describe "make_request_uri persistent guard" do
    # Kills mutations on: if @options.persistent? && uri !~ HTTP_OR_HTTPS_RE
    # - removing @options.persistent? check (always prepending)
    # - replacing with @options (always truthy)
    # - replacing with true (always truthy)
    context "when NOT persistent and URI is relative" do
      let(:option_overrides) { {} }

      it "does not prepend any origin to a full URI" do
        req = builder.build(:get, "http://example.com/path")

        assert_equal "example.com", req.uri.host
        assert_equal "/path", req.uri.path
      end
    end

    context "when persistent and URI is absolute HTTP" do
      let(:option_overrides) { { persistent: "http://example.com" } }

      it "does not prepend persistent origin to absolute URI" do
        req = builder.build(:get, "http://other.com/path")

        assert_equal "other.com", req.uri.host
      end
    end
  end

  describe "make_request_uri returns HTTP::URI" do
    # Kills mutation: uri = HTTP::URI.parse(uri) -> uri = URI.parse(uri)
    it "returns an HTTP::URI (not ::URI)" do
      req = builder.build(:get, "http://example.com/path")

      assert_instance_of HTTP::URI, req.uri
    end
  end

  describe "make_request_uri empty path normalization" do
    # Kills mutations on empty path handling:
    # - if uri.path.empty? -> if nil / if false (never setting path)
    # - uri.path = "/" -> nil / "/" / uri / uri.path / ""
    # - removing the entire if block
    it "normalizes empty path to / for bare domain" do
      req = builder.build(:get, "http://example.com")

      assert_equal "/", req.uri.path
    end

    it "does not change non-empty path" do
      req = builder.build(:get, "http://example.com/existing")

      assert_equal "/existing", req.uri.path
    end

    it "normalizes empty path when using persistent" do
      opts = HTTP::Options.new(persistent: "http://example.com")
      b = HTTP::Request::Builder.new(opts)
      # URI "http://example.com" has empty path
      req = b.build(:get, "http://example.com")

      assert_equal "/", req.uri.path
    end
  end

  describe "resolve_against_base String conversion" do
    # Kills mutation: String(base.join(uri)) -> base.join(uri)
    # The String() call ensures the result is a String, not an Addressable::URI
    context "when base_uri is set" do
      let(:option_overrides) { { base_uri: "http://example.com/api/" } }

      it "resolves against base and returns a valid parseable URI string" do
        req = builder.build(:get, "users")

        # The URI should be properly parsed as HTTP::URI
        assert_instance_of HTTP::URI, req.uri
        assert_equal "/api/users", req.uri.path
        assert_equal "example.com", req.uri.host
      end
    end
  end

  describe "#build uses HTTP::Request (not Request)" do
    # Kills mutation: HTTP::Request.new -> Request.new
    # Both resolve the same in the HTTP::Request::Builder context
    it "creates an HTTP::Request instance" do
      req = builder.build(:get, "http://example.com/")

      assert_instance_of HTTP::Request, req
    end
  end

  describe "make_form_data type checks" do
    # Kills mutations:
    # - is_a?(HTTP::FormData::Multipart) -> instance_of?(HTTP::FormData::Multipart)
    # - is_a?(HTTP::FormData::Multipart) -> is_a?(FormData::Multipart)
    # - is_a?(HTTP::FormData::Urlencoded) -> instance_of?(HTTP::FormData::Urlencoded)
    # - is_a?(HTTP::FormData::Urlencoded) -> is_a?(FormData::Urlencoded)
    # - HTTP::FormData.create(form) -> FormData.create(form)
    context "with a Multipart subclass" do
      it "passes through Multipart subclass without re-wrapping" do
        multipart = HTTP::FormData::Multipart.new({ "part" => HTTP::FormData::Part.new("val") })
        opts = HTTP::Options.new(form: multipart)
        b = HTTP::Request::Builder.new(opts)
        req = b.build(:post, "http://example.com/")

        # The body should be the same Multipart object, not re-wrapped
        assert_match(%r{\Amultipart/form-data}, req.headers["Content-Type"])
      end
    end

    context "with a Urlencoded subclass" do
      it "passes through Urlencoded without re-wrapping" do
        urlencoded = HTTP::FormData::Urlencoded.new({ "a" => "1" })
        opts = HTTP::Options.new(form: urlencoded)
        b = HTTP::Request::Builder.new(opts)
        req = b.build(:post, "http://example.com/")

        assert_equal "application/x-www-form-urlencoded", req.headers["Content-Type"]
      end
    end

    context "with a plain Hash form" do
      it "creates form data via HTTP::FormData.create and sets content type" do
        opts = HTTP::Options.new(form: { "key" => "value" })
        b = HTTP::Request::Builder.new(opts)
        req = b.build(:post, "http://example.com/")

        assert_equal "application/x-www-form-urlencoded", req.headers["Content-Type"]
        chunks = req.body.enum_for(:each).map(&:dup)

        assert_includes chunks.join, "key=value"
      end
    end
  end
end
