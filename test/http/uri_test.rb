# frozen_string_literal: true

require "test_helper"

describe HTTP::URI do
  cover "HTTP::URI*"
  let(:example_ipv6_address) { "2606:2800:220:1:248:1893:25c8:1946" }

  let(:example_http_uri_string)  { "http://example.com" }
  let(:example_https_uri_string) { "https://example.com" }
  let(:example_ipv6_uri_string) { "https://[#{example_ipv6_address}]" }

  let(:http_uri)  { HTTP::URI.parse(example_http_uri_string) }
  let(:https_uri) { HTTP::URI.parse(example_https_uri_string) }
  let(:ipv6_uri)  { HTTP::URI.parse(example_ipv6_uri_string) }

  it "knows URI schemes" do
    assert_equal "http", http_uri.scheme
    assert_equal "https", https_uri.scheme
  end

  it "sets default ports for HTTP URIs" do
    assert_equal 80, http_uri.port
  end

  it "sets default ports for HTTPS URIs" do
    assert_equal 443, https_uri.port
  end

  describe "#host" do
    it "strips brackets from IPv6 addresses" do
      assert_equal "2606:2800:220:1:248:1893:25c8:1946", ipv6_uri.host
    end
  end

  describe "#normalized_host" do
    it "strips brackets from IPv6 addresses" do
      assert_equal "2606:2800:220:1:248:1893:25c8:1946", ipv6_uri.normalized_host
    end
  end

  describe "#inspect" do
    it "returns a human-readable representation" do
      assert_match(%r{#<HTTP::URI:0x\h+ URI:http://example\.com>}, http_uri.inspect)
    end
  end

  describe "#host=" do
    it "updates cached values for #host and #normalized_host" do
      assert_equal "example.com", http_uri.host
      assert_equal "example.com", http_uri.normalized_host

      http_uri.host = "[#{example_ipv6_address}]"

      assert_equal example_ipv6_address, http_uri.host
      assert_equal example_ipv6_address, http_uri.normalized_host
    end

    it "ensures IPv6 addresses are bracketed in the raw host" do
      assert_equal "example.com", http_uri.host
      assert_equal "example.com", http_uri.normalized_host

      http_uri.host = example_ipv6_address

      assert_equal example_ipv6_address, http_uri.host
      assert_equal example_ipv6_address, http_uri.normalized_host
      assert_equal "[#{example_ipv6_address}]", http_uri.instance_variable_get(:@raw_host)
    end
  end

  describe ".form_encode" do
    it "encodes key/value pairs" do
      assert_equal "foo=bar&baz=quux", HTTP::URI.form_encode({ foo: "bar", baz: "quux" })
    end
  end

  describe "#initialize" do
    it "raises ArgumentError for positional argument" do
      assert_raises(ArgumentError) { HTTP::URI.new(42) }
    end
  end

  describe "#http?" do
    it "returns true for HTTP URIs" do
      assert_predicate http_uri, :http?
    end

    it "returns false for HTTPS URIs" do
      refute_predicate https_uri, :http?
    end
  end

  describe "#eql?" do
    it "returns true for equivalent URIs" do
      assert http_uri.eql?(HTTP::URI.parse(example_http_uri_string))
    end

    it "returns false for non-URI objects" do
      refute http_uri.eql?("http://example.com")
    end
  end

  describe "#hash" do
    it "returns an Integer" do
      assert_kind_of Integer, http_uri.hash
    end
  end

  describe "#dup" do
    it "doesn't share internal value between duplicates" do
      duplicated_uri = http_uri.dup
      duplicated_uri.host = "example.org"

      assert_equal "http://example.org", duplicated_uri.to_s
      assert_equal "http://example.com", http_uri.to_s
    end

    it "returns an HTTP::URI instance" do
      assert_instance_of HTTP::URI, http_uri.dup
    end

    it "preserves all URI components" do
      uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")
      duped = uri.dup

      assert_equal "http", duped.scheme
      assert_equal "user", duped.user
      assert_equal "pass", duped.password
      assert_equal "example.com", duped.host
      assert_equal 8080, duped.port
      assert_equal "/path", duped.path
      assert_equal "q=1", duped.query
      assert_equal "frag", duped.fragment
    end

    it "preserves IPv6 host with brackets" do
      duped = ipv6_uri.dup

      assert_equal example_ipv6_address, duped.host
      assert_equal "https://[#{example_ipv6_address}]", duped.to_s
    end
  end

  describe ".parse" do
    it "returns the same object when given an HTTP::URI" do
      assert_same http_uri, HTTP::URI.parse(http_uri)
    end

    it "returns a new HTTP::URI when given a string" do
      result = HTTP::URI.parse("http://example.com")

      assert_instance_of HTTP::URI, result
    end

    it "returns the same object when given a URI subclass instance" do
      subclass = Class.new(HTTP::URI)
      sub_uri = subclass.new(scheme: "http", host: "example.com")
      # is_a?(self) returns true for subclasses; instance_of? does not
      assert_same sub_uri, HTTP::URI.parse(sub_uri)
    end

    it "raises InvalidError for nil" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::URI.parse(nil)
      end
      assert_equal "invalid URI: nil", err.message
    end

    it "raises InvalidError for malformed URI" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::URI.parse(":")
      end
      assert_equal 'invalid URI: ":"', err.message
    end
  end

  describe ".form_encode" do
    it "sorts key/value pairs when sort is true" do
      unsorted = HTTP::URI.form_encode([[:z, 1], [:a, 2]])
      sorted   = HTTP::URI.form_encode([[:z, 1], [:a, 2]], sort: true)

      assert_equal "z=1&a=2", unsorted
      assert_equal "a=2&z=1", sorted
    end

    it "encodes newlines as %0A" do
      assert_equal "text=hello%0Aworld", HTTP::URI.form_encode({ text: "hello\nworld" })
    end

    it "sorts by string representation of keys" do
      result = HTTP::URI.form_encode([[2, "b"], [10, "a"]], sort: true)

      assert_equal "10=a&2=b", result
    end
  end

  describe ".percent_encode" do
    it "returns nil when given nil" do
      assert_nil HTTP::URI.send(:percent_encode, nil)
    end

    it "returns the same string when no encoding is needed" do
      assert_equal "hello", HTTP::URI.send(:percent_encode, "hello")
    end

    it "encodes non-ASCII characters as percent-encoded UTF-8 bytes" do
      assert_equal "h%C3%A9llo", HTTP::URI.send(:percent_encode, "héllo")
    end

    it "encodes multi-byte characters into multiple percent-encoded sequences" do
      # U+1F600 (grinning face) is 4 bytes in UTF-8: F0 9F 98 80
      result = HTTP::URI.send(:percent_encode, "\u{1F600}")

      assert_equal "%F0%9F%98%80", result
    end

    it "encodes spaces as %20" do
      assert_equal "hello%20world", HTTP::URI.send(:percent_encode, "hello world")
    end

    it "does not encode printable ASCII characters (0x21-0x7E)" do
      printable = (0x21..0x7E).map(&:chr).join

      assert_equal printable, HTTP::URI.send(:percent_encode, printable)
    end

    it "uses uppercase hex digits in percent encoding" do
      result = HTTP::URI.send(:percent_encode, "\xFF".b.encode(Encoding::UTF_8, Encoding::ISO_8859_1))

      assert_equal "%C3%BF", result
    end
  end

  describe ".remove_dot_segments" do
    def remove_dot_segments(path)
      HTTP::URI.send(:remove_dot_segments, path)
    end

    it "resolves parent directory references" do
      assert_equal "/a/c", remove_dot_segments("/a/b/../c")
    end

    it "removes current directory references" do
      assert_equal "/a/b/c", remove_dot_segments("/a/./b/c")
    end

    it "resolves multiple parent references" do
      assert_equal "/c", remove_dot_segments("/a/b/../../c")
    end

    it "clamps parent references above root" do
      assert_equal "/a", remove_dot_segments("/../a")
    end

    it "preserves paths without dot segments" do
      assert_equal "/a/b/c", remove_dot_segments("/a/b/c")
    end

    it "preserves trailing slash after parent reference" do
      assert_equal "/a/", remove_dot_segments("/a/b/..")
    end

    it "resolves current directory at end of path" do
      assert_equal "/a/b/", remove_dot_segments("/a/b/.")
    end

    it "handles standalone dot" do
      assert_equal "", remove_dot_segments(".")
    end

    it "handles standalone dot-dot" do
      assert_equal "", remove_dot_segments("..")
    end

    it "handles leading dot-slash prefix" do
      assert_equal "a", remove_dot_segments("./a")
    end

    it "handles leading dot-dot-slash prefix" do
      assert_equal "a", remove_dot_segments("../a")
    end

    it "handles empty path" do
      assert_equal "", remove_dot_segments("")
    end

    it "pops empty segment when dot-dot follows double slash" do
      assert_equal "/", remove_dot_segments("//..")
    end
  end

  describe "NORMALIZER" do
    it "normalizes an empty path to /" do
      result = HTTP::URI::NORMALIZER.call("http://example.com")

      assert_equal "/", result.path
    end

    it "preserves non-empty paths" do
      result = HTTP::URI::NORMALIZER.call("http://example.com/foo/bar")

      assert_equal "/foo/bar", result.path
    end

    it "removes dot segments from paths" do
      result = HTTP::URI::NORMALIZER.call("http://example.com/a/b/../c")

      assert_equal "/a/c", result.path
    end

    it "percent-encodes non-ASCII characters in paths" do
      result = HTTP::URI::NORMALIZER.call("http://example.com/p\u00E4th")

      assert_includes result.path, "%"
    end

    it "percent-encodes non-ASCII characters in query strings" do
      result = HTTP::URI::NORMALIZER.call("http://example.com/?q=v\u00E4lue")

      assert_includes result.query, "%"
    end

    it "returns an HTTP::URI instance" do
      assert_instance_of HTTP::URI, HTTP::URI::NORMALIZER.call("http://example.com/path")
    end

    it "lowercases the scheme" do
      result = HTTP::URI::NORMALIZER.call("HTTP://example.com")

      assert_equal "http", result.scheme
    end

    it "lowercases the host" do
      result = HTTP::URI::NORMALIZER.call("http://EXAMPLE.COM")

      assert_equal "example.com", result.host
    end

    it "omits default HTTP port" do
      result = HTTP::URI::NORMALIZER.call("http://example.com:80/path")

      assert_equal "http://example.com/path", result.to_s
    end

    it "omits default HTTPS port" do
      result = HTTP::URI::NORMALIZER.call("https://example.com:443/path")

      assert_equal "https://example.com/path", result.to_s
    end

    it "preserves non-default port" do
      result = HTTP::URI::NORMALIZER.call("http://example.com:8080/path")

      assert_equal "http://example.com:8080/path", result.to_s
    end

    it "preserves IPv6 host" do
      result = HTTP::URI::NORMALIZER.call("http://[::1]:8080/path")

      assert_equal "http://[::1]:8080/path", result.to_s
    end

    it "preserves user info" do
      result = HTTP::URI::NORMALIZER.call("http://user:pass@example.com/path")

      assert_equal "user", result.user
      assert_equal "pass", result.password
    end

    it "preserves fragment" do
      result = HTTP::URI::NORMALIZER.call("http://example.com/path#frag")

      assert_equal "frag", result.fragment
    end
  end

  describe "#==" do
    it "returns false when compared to a non-URI object" do
      refute_equal "http://example.com", http_uri
    end

    it "returns true for URIs that normalize to the same form" do
      uri1 = HTTP::URI.parse("HTTP://EXAMPLE.COM")
      uri2 = HTTP::URI.parse("http://example.com")

      assert_equal uri1, uri2
    end

    it "returns false for URIs that normalize differently" do
      uri1 = HTTP::URI.parse("http://example.com/a")
      uri2 = HTTP::URI.parse("http://example.com/b")

      refute_equal uri1, uri2
    end

    it "returns true when compared to a URI subclass instance" do
      subclass = Class.new(HTTP::URI)
      sub_uri = subclass.new(scheme: "http", host: "example.com")

      assert_equal http_uri, sub_uri
    end
  end

  describe "#eql?" do
    it "returns false for URIs with different string representations" do
      uri1 = HTTP::URI.parse("http://example.com")
      uri2 = HTTP::URI.parse("http://example.com/")

      refute uri1.eql?(uri2)
    end

    it "returns true for a URI subclass instance with same string" do
      subclass = Class.new(HTTP::URI)
      sub_uri = subclass.new(scheme: "http", host: "example.com")

      assert http_uri.eql?(sub_uri)
    end
  end

  describe "#hash" do
    it "returns the same value on repeated calls" do
      first  = http_uri.hash
      second = http_uri.hash

      assert_equal first, second
    end

    it "returns a composite hash of class and string representation" do
      assert_equal [HTTP::URI, http_uri.to_s].hash, http_uri.hash
    end
  end

  describe "#port" do
    it "returns the explicit port when one is set" do
      uri = HTTP::URI.parse("http://example.com:8080")

      assert_equal 8080, uri.port
    end
  end

  describe "#origin" do
    it "returns scheme and host for HTTP URIs" do
      assert_equal "http://example.com", http_uri.origin
    end

    it "returns scheme and host for HTTPS URIs" do
      assert_equal "https://example.com", https_uri.origin
    end

    it "includes non-default port" do
      uri = HTTP::URI.parse("http://example.com:8080")

      assert_equal "http://example.com:8080", uri.origin
    end

    it "omits default HTTP port" do
      uri = HTTP::URI.parse("http://example.com:80")

      assert_equal "http://example.com", uri.origin
    end

    it "omits default HTTPS port" do
      uri = HTTP::URI.parse("https://example.com:443")

      assert_equal "https://example.com", uri.origin
    end

    it "normalizes scheme to lowercase" do
      uri = HTTP::URI.parse("HTTP://example.com")

      assert_equal "http://example.com", uri.origin
    end

    it "normalizes host to lowercase" do
      uri = HTTP::URI.parse("http://EXAMPLE.COM")

      assert_equal "http://example.com", uri.origin
    end

    it "preserves IPv6 brackets" do
      assert_equal "https://[2606:2800:220:1:248:1893:25c8:1946]", ipv6_uri.origin
    end

    it "excludes user info" do
      uri = HTTP::URI.parse("http://user:pass@example.com")

      assert_equal "http://example.com", uri.origin
    end

    it "handles URI with no scheme" do
      uri = HTTP::URI.new(host: "example.com")

      assert_equal "://example.com", uri.origin
    end

    it "handles URI with no host" do
      uri = HTTP::URI.new(path: "/foo")

      assert_equal "://", uri.origin
    end
  end

  describe "#request_uri" do
    it "returns path for a simple URI" do
      uri = HTTP::URI.parse("http://example.com/path")

      assert_equal "/path", uri.request_uri
    end

    it "returns path and query" do
      uri = HTTP::URI.parse("http://example.com/path?q=1")

      assert_equal "/path?q=1", uri.request_uri
    end

    it "returns / for empty path" do
      assert_equal "/", http_uri.request_uri
    end

    it "returns / with query for empty path" do
      uri = HTTP::URI.parse("http://example.com?q=1")

      assert_equal "/?q=1", uri.request_uri
    end

    it "preserves trailing ? with empty query" do
      uri = HTTP::URI.parse("http://example.com/path?")

      assert_equal "/path?", uri.request_uri
    end
  end

  describe "#omit" do
    let(:full_uri) { HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag") }

    it "returns an HTTP::URI instance" do
      assert_instance_of HTTP::URI, full_uri.omit(:fragment)
    end

    it "removes the fragment component" do
      assert_nil full_uri.omit(:fragment).fragment
    end

    it "removes multiple components" do
      result = full_uri.omit(:query, :fragment)

      assert_nil result.query
      assert_nil result.fragment
    end

    it "preserves all other components when omitting fragment" do
      result = full_uri.omit(:fragment)

      assert_equal "http", result.scheme
      assert_equal "user", result.user
      assert_equal "pass", result.password
      assert_equal "example.com", result.host
      assert_equal 8080, result.port
      assert_equal "/path", result.path
      assert_equal "q=1", result.query
    end

    it "does not add default port when omitting components" do
      uri = HTTP::URI.parse("http://example.com/path#frag")

      assert_equal "http://example.com/path", uri.omit(:fragment).to_s
    end

    it "preserves IPv6 host when omitting components" do
      uri = HTTP::URI.parse("https://[::1]:8080/path#frag")

      assert_equal "https://[::1]:8080/path", uri.omit(:fragment).to_s
    end

    it "returns unchanged URI when no components given" do
      assert_equal full_uri.to_s, full_uri.omit.to_s
    end
  end

  describe "#join" do
    it "resolves a relative path" do
      result = HTTP::URI.parse("http://example.com/foo/").join("bar")

      assert_equal "http://example.com/foo/bar", result.to_s
    end

    it "resolves an absolute path" do
      result = HTTP::URI.parse("http://example.com/foo").join("/bar")

      assert_equal "http://example.com/bar", result.to_s
    end

    it "resolves a full URI" do
      result = HTTP::URI.parse("http://example.com/foo").join("http://other.com/bar")

      assert_equal "http://other.com/bar", result.to_s
    end

    it "returns an HTTP::URI instance" do
      result = HTTP::URI.parse("http://example.com/foo/").join("bar")

      assert_instance_of HTTP::URI, result
    end

    it "accepts an HTTP::URI as argument" do
      other = HTTP::URI.parse("http://other.com/bar")
      result = HTTP::URI.parse("http://example.com/foo").join(other)

      assert_equal "http://other.com/bar", result.to_s
    end

    it "percent-encodes non-ASCII characters in the base URI" do
      result = HTTP::URI.parse("http://example.com/K\u00F6nig/").join("bar")

      assert_equal "http://example.com/K%C3%B6nig/bar", result.to_s
    end

    it "percent-encodes non-ASCII characters in the other URI" do
      result = HTTP::URI.parse("http://example.com/").join("/K\u00F6nig")

      assert_equal "http://example.com/K%C3%B6nig", result.to_s
    end
  end

  describe "#http?" do
    it "returns false for non-HTTP/HTTPS schemes" do
      uri = HTTP::URI.parse("ftp://example.com")

      refute_predicate uri, :http?
    end
  end

  describe "#https?" do
    it "returns true for HTTPS URIs" do
      assert_predicate https_uri, :https?
    end

    it "returns false for HTTP URIs" do
      refute_predicate http_uri, :https?
    end

    it "returns false for non-HTTP/HTTPS schemes" do
      uri = HTTP::URI.parse("ftp://example.com")

      refute_predicate uri, :https?
    end
  end

  describe "#to_s" do
    it "returns the string representation" do
      assert_equal "http://example.com", http_uri.to_s
    end
  end

  describe "#to_str" do
    it "is aliased to to_s" do
      assert_equal http_uri.to_s, http_uri.to_str
    end
  end

  describe "#inspect" do
    it "includes the class name" do
      assert_includes http_uri.inspect, "HTTP::URI"
    end

    it "includes the URI string" do
      assert_includes http_uri.inspect, "URI:http://example.com"
    end

    it "formats the object_id correctly with << 1" do
      expected_hex = format("%014x", http_uri.object_id << 1)

      assert_includes http_uri.inspect, expected_hex
    end
  end

  describe "#initialize" do
    it "accepts keyword arguments" do
      uri = HTTP::URI.new(scheme: "http", host: "example.com")

      assert_equal "http", uri.scheme
      assert_equal "example.com", uri.host
    end

    it "raises ArgumentError for an Addressable::URI" do
      addr_uri = Addressable::URI.parse("http://example.com")

      assert_raises(ArgumentError) { HTTP::URI.new(addr_uri) }
    end

    it "raises ArgumentError for a positional argument" do
      assert_raises(ArgumentError) { HTTP::URI.new(42) }
    end

    it "works with no arguments" do
      uri = HTTP::URI.new

      assert_instance_of HTTP::URI, uri
    end
  end

  describe "#deconstruct_keys" do
    let(:full_uri) { HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag") }

    it "returns all keys when given nil" do
      result = full_uri.deconstruct_keys(nil)

      assert_equal "http", result[:scheme]
      assert_equal "example.com", result[:host]
      assert_equal 8080, result[:port]
      assert_equal "/path", result[:path]
      assert_equal "q=1", result[:query]
      assert_equal "frag", result[:fragment]
      assert_equal "user", result[:user]
      assert_equal "pass", result[:password]
    end

    it "returns only requested keys" do
      result = http_uri.deconstruct_keys(%i[scheme host])

      assert_equal({ scheme: "http", host: "example.com" }, result)
    end

    it "excludes unrequested keys" do
      result = http_uri.deconstruct_keys([:host])

      refute_includes result.keys, :scheme
      refute_includes result.keys, :port
    end

    it "returns empty hash for empty keys" do
      assert_equal({}, http_uri.deconstruct_keys([]))
    end

    it "returns correct port for HTTPS URIs" do
      assert_equal 443, https_uri.deconstruct_keys([:port])[:port]
    end

    it "supports pattern matching with case/in" do
      matched = case http_uri
                in { scheme: "http", host: /example/ }
                  true
                else
                  false
                end

      assert matched
    end
  end

  describe "process_ipv6_brackets (via host=)" do
    it "handles IPv4 addresses" do
      http_uri.host = "192.168.1.1"

      assert_equal "192.168.1.1", http_uri.host
    end

    it "handles regular hostnames" do
      http_uri.host = "example.org"

      assert_equal "example.org", http_uri.host
    end

    it "handles invalid IP address strings gracefully" do
      http_uri.host = "not-an-ip"

      assert_equal "not-an-ip", http_uri.host
    end
  end

  describe ".parse (TypeError/NoMethodError rescue)" do
    it "raises InvalidError with message containing inspect for non-stringable objects" do
      obj = Object.new
      def obj.to_str
        raise NoMethodError
      end

      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::URI.parse(obj)
      end
      assert_kind_of HTTP::URI::InvalidError, err
      assert_includes err.message, "invalid URI: "
      assert_includes err.message, obj.inspect
      refute_equal obj.inspect, err.message
    end

    it "raises InvalidError for an object whose to_str raises TypeError" do
      obj = Object.new
      def obj.to_str
        raise TypeError
      end

      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::URI.parse(obj)
      end
      assert_kind_of HTTP::URI::InvalidError, err
      assert_includes err.message, obj.inspect
      refute_equal obj.inspect, err.message
    end
  end

  describe ".parse via parse_components" do
    it "parses a non-ASCII URI with all components via Addressable" do
      uri = HTTP::URI.parse("http://us\u00E9r:p\u00E4ss@ex\u00E4mple.com:9090/p\u00E4th?q=v\u00E4l#fr\u00E4g")

      assert_equal "us\u00E9r", uri.user
      assert_equal "p\u00E4ss", uri.password
      assert_equal 9090, uri.port
      assert_includes String(uri), "fr\u00E4g"
    end

    it "parses an ASCII URI via stdlib" do
      uri = HTTP::URI.parse("http://example.com/path?q=1#frag")

      assert_equal "http", uri.scheme
      assert_equal "example.com", uri.host
      assert_equal "/path", uri.path
      assert_equal "q=1", uri.query
      assert_equal "frag", uri.fragment
    end

    it "strips default port when parsing ASCII URI via stdlib" do
      uri = HTTP::URI.parse("http://example.com:80/path")

      assert_equal "http://example.com/path", uri.to_s
    end

    it "falls back to Addressable when stdlib fails on ASCII input" do
      uri = HTTP::URI.parse("http://example.com/path with spaces")

      assert_equal "http", uri.scheme
      assert_equal "example.com", uri.host
    end

    it "raises InvalidError for invalid non-ASCII URI via Addressable" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::URI.parse("ht\u00FCtp://[invalid")
      end
      assert_kind_of HTTP::URI::InvalidError, err
      assert_includes err.message, "invalid URI:"
      assert_includes err.message, "invalid"
    end

    it "raises InvalidError for stdlib-invalid URI with correct message" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::URI.parse("http://exam ple.com")
      end
      assert_kind_of HTTP::URI::InvalidError, err
      assert_includes err.message, "invalid URI:"
      assert_includes err.message, "exam ple.com"
    end

    it "parses non-ASCII URI preserving fragment" do
      uri = HTTP::URI.parse("http://ex\u00E4mple.com/path#sec\u00F6tion")

      assert_equal "sec\u00F6tion", uri.fragment
    end

    it "parses non-ASCII URI preserving user without password" do
      uri = HTTP::URI.parse("http://\u00FCser@ex\u00E4mple.com/")

      assert_equal "\u00FCser", uri.user
      assert_nil uri.password
    end

    it "routes ASCII control characters to Addressable" do
      uri = HTTP::URI.parse("http://example.com/?\x00\x7F\n")

      assert_equal "\x00\x7F\n", uri.query
    end
  end

  describe "#to_s" do
    it "serializes scheme-only URI" do
      uri = HTTP::URI.new(scheme: "http")

      assert_equal "http:", uri.to_s
    end

    it "omits scheme prefix when scheme is nil" do
      uri = HTTP::URI.new(host: "example.com", path: "/path")

      assert_equal "//example.com/path", uri.to_s
    end

    it "serializes URI with user and password" do
      uri = HTTP::URI.new(scheme: "http", user: "admin", password: "secret", host: "example.com")

      assert_equal "http://admin:secret@example.com", uri.to_s
    end

    it "serializes URI with user but no password" do
      uri = HTTP::URI.new(scheme: "http", user: "admin", host: "example.com")

      assert_equal "http://admin@example.com", uri.to_s
    end

    it "serializes URI with explicit port" do
      uri = HTTP::URI.new(scheme: "http", host: "example.com", port: 8080)

      assert_equal "http://example.com:8080", uri.to_s
    end

    it "serializes URI with query" do
      uri = HTTP::URI.new(scheme: "http", host: "example.com", path: "/path", query: "a=1")

      assert_equal "http://example.com/path?a=1", uri.to_s
    end

    it "serializes URI with fragment" do
      uri = HTTP::URI.new(scheme: "http", host: "example.com", path: "/path", fragment: "sec")

      assert_equal "http://example.com/path#sec", uri.to_s
    end

    it "serializes URI with all components" do
      uri = HTTP::URI.new(
        scheme: "http", user: "u", password: "p", host: "h.com",
        port: 9090, path: "/x", query: "q=1", fragment: "f"
      )

      assert_equal "http://u:p@h.com:9090/x?q=1#f", uri.to_s
    end

    it "serializes path-only URI" do
      uri = HTTP::URI.new(path: "/just/a/path")

      assert_equal "/just/a/path", uri.to_s
    end

    it "serializes URI without host omitting //" do
      uri = HTTP::URI.new(scheme: "mailto", path: "user@example.com")

      assert_equal "mailto:user@example.com", uri.to_s
    end

    it "serializes query-only URI without host" do
      uri = HTTP::URI.new(path: "/p", query: "q=1")

      assert_equal "/p?q=1", uri.to_s
    end

    it "serializes fragment-only URI without host" do
      uri = HTTP::URI.new(path: "/p", fragment: "f")

      assert_equal "/p#f", uri.to_s
    end
  end

  describe "#normalize" do
    it "lowercases the scheme" do
      uri = HTTP::URI.new(scheme: "HTTP", host: "example.com")

      assert_equal "http", uri.normalize.scheme
    end

    it "lowercases the host" do
      uri = HTTP::URI.new(scheme: "http", host: "EXAMPLE.COM")

      assert_equal "example.com", uri.normalize.host
    end

    it "strips default port" do
      uri = HTTP::URI.new(scheme: "http", host: "example.com", port: 80, path: "/path")

      assert_nil uri.normalize.instance_variable_get(:@port)
    end

    it "preserves non-default port" do
      uri = HTTP::URI.parse("http://example.com:8080/path")
      normalized = uri.normalize

      assert_equal 8080, normalized.instance_variable_get(:@port)
    end

    it "normalizes empty path to / when host is present" do
      uri = HTTP::URI.new(scheme: "http", host: "example.com")

      assert_equal "/", uri.normalize.path
    end

    it "preserves non-empty path" do
      uri = HTTP::URI.parse("http://example.com/foo")

      assert_equal "/foo", uri.normalize.path
    end

    it "preserves user" do
      uri = HTTP::URI.parse("http://myuser@example.com/")

      assert_equal "myuser", uri.normalize.user
    end

    it "preserves password" do
      uri = HTTP::URI.parse("http://u:mypass@example.com/")

      assert_equal "mypass", uri.normalize.password
    end

    it "preserves query" do
      uri = HTTP::URI.parse("http://example.com/?q=val")

      assert_equal "q=val", uri.normalize.query
    end

    it "preserves fragment" do
      uri = HTTP::URI.parse("http://example.com/#frag")

      assert_equal "frag", uri.normalize.fragment
    end

    it "handles nil scheme" do
      uri = HTTP::URI.new(host: "example.com")

      assert_nil uri.normalize.scheme
    end

    it "handles nil host" do
      uri = HTTP::URI.new(scheme: "http", path: "/path")

      assert_nil uri.normalize.host
    end

    it "does not normalize empty path to / without host" do
      uri = HTTP::URI.new(scheme: "http")

      assert_equal "", uri.normalize.path
    end

    it "returns a complete normalized string" do
      uri = HTTP::URI.parse("HTTP://USER:PASS@EXAMPLE.COM:8080/path?q=1#frag")
      normalized = uri.normalize

      assert_equal "http://USER:PASS@example.com:8080/path?q=1#frag", String(normalized)
    end
  end

  describe "#normalized_host" do
    it "lowercases the host" do
      uri = HTTP::URI.new(host: "EXAMPLE.COM")

      assert_equal "example.com", uri.normalized_host
    end

    it "decodes percent-encoded characters" do
      uri = HTTP::URI.new(host: "%65%78ample.com")

      assert_equal "example.com", uri.normalized_host
    end

    it "decodes multiple percent-encoded characters" do
      uri = HTTP::URI.new(host: "%65%78%61mple.com")

      assert_equal "example.com", uri.normalized_host
    end

    it "strips trailing dot from domain" do
      uri = HTTP::URI.new(host: "example.com.")

      assert_equal "example.com", uri.normalized_host
    end

    it "returns nil for nil host" do
      uri = HTTP::URI.new

      assert_nil uri.normalized_host
    end

    it "encodes IDN non-ASCII hostnames to ASCII" do
      uri = HTTP::URI.new(host: "ex\u00E4mple.com")

      assert_equal "xn--exmple-cua.com", uri.normalized_host
    end

    it "does not IDN-encode already-ASCII hostnames" do
      uri = HTTP::URI.new(host: "example.com")

      assert_equal "example.com", uri.normalized_host
    end
  end

  describe "#host= normalized_host update" do
    it "applies normalize_host to the new host" do
      uri = HTTP::URI.parse("http://example.com")
      uri.host = "NEW-HOST.COM."

      assert_equal "new-host.com", uri.normalized_host
    end
  end

  describe "#default_port" do
    it "returns default port for uppercase scheme" do
      uri = HTTP::URI.new(scheme: "HTTP")

      assert_equal 80, uri.default_port
    end

    it "returns nil for unknown scheme" do
      uri = HTTP::URI.new(scheme: "ftp")

      assert_nil uri.default_port
    end

    it "returns default port for ws scheme" do
      uri = HTTP::URI.new(scheme: "ws")

      assert_equal 80, uri.default_port
    end

    it "returns default port for wss scheme" do
      uri = HTTP::URI.new(scheme: "wss")

      assert_equal 443, uri.default_port
    end
  end

  describe "#origin" do
    it "lowercases an uppercase scheme via String().downcase" do
      uri = HTTP::URI.new(scheme: "HTTP", host: "example.com")

      assert_equal "http://example.com", uri.origin
    end
  end

  describe "#process_ipv6_brackets" do
    it "returns nil host as nil" do
      uri = HTTP::URI.new(host: nil)

      assert_nil uri.host
    end

    it "does not strip brackets from IPv4 addresses" do
      uri = HTTP::URI.new(host: "192.168.1.1")

      assert_equal "192.168.1.1", uri.host
      assert_equal "192.168.1.1", uri.instance_variable_get(:@raw_host)
    end

    it "does not bracket IPv4 addresses in host=" do
      uri = HTTP::URI.parse("http://example.com")
      uri.host = "10.0.0.1"

      assert_equal "http://10.0.0.1", uri.to_s
    end
  end

  describe ".parse error messages" do
    it "uses inspect in the rescue for TypeError/NoMethodError" do
      obj = Object.new
      def obj.to_s
        "CUSTOM_TO_S"
      end

      def obj.to_str
        raise NoMethodError
      end

      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::URI.parse(obj)
      end

      refute_includes err.message, "CUSTOM_TO_S"
    end
  end

  describe "#dup vs super" do
    it "does not copy memoized hash ivar" do
      uri = HTTP::URI.parse("http://example.com")
      uri.hash # memoize @hash

      duped = uri.dup

      refute duped.instance_variable_defined?(:@hash)
    end
  end

  describe "#normalize port stripping" do
    it "strips port 443 for https" do
      uri = HTTP::URI.new(scheme: "https", host: "example.com", port: 443, path: "/")

      assert_nil uri.normalize.instance_variable_get(:@port)
    end

    it "does not strip non-default port" do
      uri = HTTP::URI.new(scheme: "http", host: "example.com", port: 9090, path: "/")

      assert_equal 9090, uri.normalize.instance_variable_get(:@port)
    end
  end
end
