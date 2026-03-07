# frozen_string_literal: true

require "test_helper"

describe HTTP::Headers do
  cover "HTTP::Headers*"
  let(:headers) { HTTP::Headers.new }

  it "is Enumerable" do
    assert_kind_of Enumerable, headers
  end

  describe "#set" do
    it "sets header value" do
      headers.set "Accept", "application/json"

      assert_equal "application/json", headers["Accept"]
    end

    it "allows retrieval via normalized header name" do
      headers.set :content_type, "application/json"

      assert_equal "application/json", headers["Content-Type"]
    end

    it "overwrites previous value" do
      headers.set :set_cookie, "hoo=ray"
      headers.set :set_cookie, "woo=hoo"

      assert_equal "woo=hoo", headers["Set-Cookie"]
    end

    it "allows set multiple values" do
      headers.set :set_cookie, "hoo=ray"
      headers.set :set_cookie, %w[hoo=ray woo=hoo]

      assert_equal %w[hoo=ray woo=hoo], headers["Set-Cookie"]
    end

    it "fails with empty header name" do
      assert_raises(HTTP::HeaderError) { headers.set "", "foo bar" }
    end

    ["foo bar", "foo bar: ok\nfoo", "evil-header: evil-value\nfoo"].each do |name|
      it "fails with invalid header name (#{name.inspect})" do
        assert_raises(HTTP::HeaderError) { headers.set name, "baz" }
      end
    end

    it "fails with invalid header value" do
      assert_raises(HTTP::HeaderError) { headers.set "foo", "bar\nEvil-Header: evil-value" }
    end
  end

  describe "#[]=" do
    it "sets header value" do
      headers["Accept"] = "application/json"

      assert_equal "application/json", headers["Accept"]
    end

    it "allows retrieval via normalized header name" do
      headers[:content_type] = "application/json"

      assert_equal "application/json", headers["Content-Type"]
    end

    it "overwrites previous value" do
      headers[:set_cookie] = "hoo=ray"
      headers[:set_cookie] = "woo=hoo"

      assert_equal "woo=hoo", headers["Set-Cookie"]
    end

    it "allows set multiple values" do
      headers[:set_cookie] = "hoo=ray"
      headers[:set_cookie] = %w[hoo=ray woo=hoo]

      assert_equal %w[hoo=ray woo=hoo], headers["Set-Cookie"]
    end
  end

  describe "#delete" do
    before { headers.set "Content-Type", "application/json" }

    it "removes given header" do
      headers.delete "Content-Type"

      assert_nil headers["Content-Type"]
    end

    it "removes header that matches normalized version of specified name" do
      headers.delete :content_type

      assert_nil headers["Content-Type"]
    end

    it "calls .to_s on non-string name argument" do
      name = fake(to_s: "Content-Type")
      headers.delete name

      assert_nil headers["Content-Type"]
    end

    it "fails with empty header name" do
      assert_raises(HTTP::HeaderError) { headers.delete "" }
    end

    ["foo bar", "foo bar: ok\nfoo"].each do |name|
      it "fails with invalid header name (#{name.inspect})" do
        assert_raises(HTTP::HeaderError) { headers.delete name }
      end
    end
  end

  describe "#add" do
    it "sets header value" do
      headers.add "Accept", "application/json"

      assert_equal "application/json", headers["Accept"]
    end

    it "allows retrieval via normalized header name" do
      headers.add :content_type, "application/json"

      assert_equal "application/json", headers["Content-Type"]
    end

    it "appends new value if header exists" do
      headers.add "Set-Cookie", "hoo=ray"
      headers.add :set_cookie, "woo=hoo"

      assert_equal %w[hoo=ray woo=hoo], headers["Set-Cookie"]
    end

    it "allows append multiple values" do
      headers.add :set_cookie, "hoo=ray"
      headers.add :set_cookie, %w[woo=hoo yup=pie]

      assert_equal %w[hoo=ray woo=hoo yup=pie], headers["Set-Cookie"]
    end

    it "fails with empty header name" do
      assert_raises(HTTP::HeaderError) { headers.add("", "foobar") }
    end

    ["foo bar", "foo bar: ok\nfoo"].each do |name|
      it "fails with invalid header name (#{name.inspect})" do
        assert_raises(HTTP::HeaderError) { headers.add name, "baz" }
      end
    end

    it "fails with invalid header value" do
      assert_raises(HTTP::HeaderError) { headers.add "foo", "bar\nEvil-Header: evil-value" }
    end

    it "fails when header name is not a String or Symbol" do
      err = assert_raises(HTTP::HeaderError) { headers.add 2, "foo" }
      assert_includes err.message, "2"
    end

    it "includes inspect-formatted name in error for non-String/Symbol" do
      obj = Object.new
      def obj.to_s = "plain"
      def obj.inspect = "INSPECTED"

      err = assert_raises(HTTP::HeaderError) { headers.add obj, "foo" }
      assert_includes err.message, "INSPECTED"
    end

    it "uses normalized name as wire_name for Symbol keys in to_a" do
      headers.add :content_type, "application/json"

      assert_equal [["Content-Type", "application/json"]], headers.to_a
    end

    it "preserves original string as wire_name for String keys in to_a" do
      headers.add "auth_key", "secret"

      assert_equal [%w[auth_key secret]], headers.to_a
    end

    it "calls .to_s on Symbol name for normalization" do
      headers.add :accept, "text/html"

      assert_equal [["Accept", "text/html"]], headers.to_a
    end
  end

  describe "#get" do
    before { headers.set("Content-Type", "application/json") }

    it "returns array of associated values" do
      assert_equal %w[application/json], headers.get("Content-Type")
    end

    it "normalizes header name" do
      assert_equal %w[application/json], headers.get(:content_type)
    end

    context "when header does not exists" do
      it "returns empty array" do
        assert_equal [], headers.get(:accept)
      end
    end

    it "calls .to_s on non-string name argument" do
      name = fake(to_s: "Content-Type")

      assert_equal %w[application/json], headers.get(name)
    end

    it "fails with empty header name" do
      assert_raises(HTTP::HeaderError) { headers.get("") }
    end

    ["foo bar", "foo bar: ok\nfoo"].each do |name|
      it "fails with invalid header name (#{name.inspect})" do
        assert_raises(HTTP::HeaderError) { headers.get name }
      end
    end
  end

  describe "#[]" do
    context "when header does not exists" do
      it "returns nil" do
        assert_nil headers[:accept]
      end
    end

    context "when header has a single value" do
      before { headers.set "Content-Type", "application/json" }

      it "normalizes header name" do
        refute_nil headers[:content_type]
      end

      it "returns it returns a single value" do
        assert_equal "application/json", headers[:content_type]
      end
    end

    context "when header has a multiple values" do
      before do
        headers.add :set_cookie, "hoo=ray"
        headers.add :set_cookie, "woo=hoo"
      end

      it "normalizes header name" do
        refute_nil headers[:set_cookie]
      end

      it "returns array of associated values" do
        assert_equal %w[hoo=ray woo=hoo], headers[:set_cookie]
      end
    end

    it "returns nil for missing header (not empty array or other)" do
      headers.set "Content-Type", "text/plain"
      result = headers[:nonexistent]

      assert_nil result
    end

    it "returns a String (not Array) for single value" do
      headers.set "Content-Type", "text/plain"

      result = headers["Content-Type"]

      assert_instance_of String, result
      assert_equal "text/plain", result
    end

    it "returns an Array for multiple values" do
      headers.add :cookie, "a=1"
      headers.add :cookie, "b=2"

      result = headers[:cookie]

      assert_instance_of Array, result
      assert_equal %w[a=1 b=2], result
    end
  end

  describe "#include?" do
    before do
      headers.add :content_type, "application/json"
      headers.add :set_cookie,   "hoo=ray"
      headers.add :set_cookie,   "woo=hoo"
    end

    it "tells whenever given headers is set or not" do
      assert_includes headers, "Content-Type"
      assert_includes headers, "Set-Cookie"
      refute_includes headers, "Accept"
    end

    it "normalizes given header name" do
      assert_includes headers, :content_type
      assert_includes headers, :set_cookie
      refute_includes headers, :accept
    end

    it "calls .to_s on non-string name argument" do
      name = fake(to_s: "Content-Type")

      assert_includes headers, name
    end

    it "finds headers added with non-canonical string keys" do
      h = HTTP::Headers.new
      h.add("x-custom", "value")

      assert_includes h, "x-custom"
    end
  end

  describe "#to_h" do
    before do
      headers.add :content_type, "application/json"
      headers.add :set_cookie,   "hoo=ray"
      headers.add :set_cookie,   "woo=hoo"
    end

    it "returns a Hash" do
      assert_kind_of Hash, headers.to_h
    end

    it "returns Hash with normalized keys" do
      assert_equal %w[Content-Type Set-Cookie].sort, headers.to_h.keys.sort
    end

    context "for a header with single value" do
      it "provides a value as is" do
        assert_equal "application/json", headers.to_h["Content-Type"]
      end
    end

    context "for a header with multiple values" do
      it "provides an array of values" do
        assert_equal %w[hoo=ray woo=hoo], headers.to_h["Set-Cookie"]
      end
    end
  end

  describe "#to_a" do
    before do
      headers.add :content_type, "application/json"
      headers.add :set_cookie,   "hoo=ray"
      headers.add :set_cookie,   "woo=hoo"
    end

    it "returns an Array" do
      assert_kind_of Array, headers.to_a
    end

    it "returns Array of key/value pairs with normalized keys" do
      assert_equal [
        %w[Content-Type application/json],
        %w[Set-Cookie hoo=ray],
        %w[Set-Cookie woo=hoo]
      ], headers.to_a
    end

    it "returns two-element arrays (not three-element or one-element)" do
      headers.to_a.each do |pair|
        assert_equal 2, pair.size, "Expected each element to be a [name, value] pair"
      end
    end

    it "returns wire_name (not lookup_name) as first element" do
      h = HTTP::Headers.new
      h.add "X_Custom", "val"

      assert_equal [%w[X_Custom val]], h.to_a
    end
  end

  describe "#inspect" do
    it "returns a human-readable representation" do
      headers.set :set_cookie, %w[hoo=ray woo=hoo]

      assert_equal "#<HTTP::Headers>", headers.inspect
    end
  end

  describe "#keys" do
    before do
      headers.add :content_type, "application/json"
      headers.add :set_cookie,   "hoo=ray"
      headers.add :set_cookie,   "woo=hoo"
    end

    it "returns uniq keys only" do
      assert_equal 2, headers.keys.size
    end

    it "normalizes keys" do
      assert_includes headers.keys, "Content-Type"
      assert_includes headers.keys, "Set-Cookie"
    end
  end

  describe "#each" do
    before do
      headers.add :set_cookie,   "hoo=ray"
      headers.add :content_type, "application/json"
      headers.add :set_cookie,   "woo=hoo"
    end

    it "yields each key/value pair separatedly" do
      yielded = headers.map { |pair| pair }

      assert_equal 3, yielded.size
    end

    it "yields headers in the same order they were added" do
      yielded = headers.map { |pair| pair }

      assert_equal [
        %w[Set-Cookie hoo=ray],
        %w[Content-Type application/json],
        %w[Set-Cookie woo=hoo]
      ], yielded
    end

    it "yields header keys specified as symbols in normalized form" do
      keys = headers.each.map(&:first)

      assert_equal %w[Set-Cookie Content-Type Set-Cookie], keys
    end

    it "yields headers specified as strings without conversion" do
      headers.add "X_kEy", "value"
      keys = headers.each.map(&:first)

      assert_equal %w[Set-Cookie Content-Type Set-Cookie X_kEy], keys
    end

    it "returns self instance if block given" do
      assert_same(headers, headers.each { |*| }) # rubocop:disable Lint/EmptyBlock
    end

    it "returns Enumerator if no block given" do
      assert_kind_of Enumerator, headers.each
    end

    it "yields two-element arrays [name, value]" do
      headers.each do |pair|
        assert_equal 2, pair.size
      end
    end
  end

  describe ".empty?" do
    context "initially" do
      it "is true" do
        assert_empty headers
      end
    end

    context "when header exists" do
      before { headers.add :accept, "text/plain" }

      it "is false" do
        refute_empty headers
      end
    end

    context "when last header was removed" do
      before do
        headers.add :accept, "text/plain"
        headers.delete :accept
      end

      it "is true" do
        assert_empty headers
      end
    end
  end

  describe "#hash" do
    let(:left)  { HTTP::Headers.new }
    let(:right) { HTTP::Headers.new }

    it "equals if two headers equals" do
      left.add :accept, "text/plain"
      right.add :accept, "text/plain"

      assert_equal left.hash, right.hash
    end
  end

  describe "#==" do
    let(:left)  { HTTP::Headers.new }
    let(:right) { HTTP::Headers.new }

    it "compares header keys and values" do
      left.add :accept, "text/plain"
      right.add :accept, "text/plain"

      assert_equal left, right
    end

    it "allows comparison with Array of key/value pairs" do
      left.add :accept, "text/plain"

      assert_equal left, [%w[Accept text/plain]] # rubocop:disable Minitest/LiteralAsActualArgument
    end

    it "sensitive to headers order" do
      left.add :accept, "text/plain"
      left.add :cookie, "woo=hoo"
      right.add :cookie, "woo=hoo"
      right.add :accept, "text/plain"

      refute_equal left, right
    end

    it "sensitive to header values order" do
      left.add :cookie, "hoo=ray"
      left.add :cookie, "woo=hoo"
      right.add :cookie, "woo=hoo"
      right.add :cookie, "hoo=ray"

      refute_equal left, right
    end

    it "returns false when compared to object without #to_a" do
      left.add :accept, "text/plain"

      refute_equal left, 42
    end
  end

  describe "#dup" do
    let(:dupped) { headers.dup }

    before { headers.set :content_type, "application/json" }

    it "returns an HTTP::Headers instance" do
      assert_kind_of HTTP::Headers, dupped
    end

    it "is not the same object" do
      refute_same headers, dupped
    end

    it "has headers copied" do
      assert_equal "application/json", dupped[:content_type]
    end

    context "modifying a copy" do
      before { dupped.set :content_type, "text/plain" }

      it "modifies dupped copy" do
        assert_equal "text/plain", dupped[:content_type]
      end

      it "does not affects original headers" do
        assert_equal "application/json", headers[:content_type]
      end
    end

    it "deep copies internal pile entries so mutations to inner arrays don't leak" do
      original_pile = headers.instance_variable_get(:@pile)
      dupped_pile   = dupped.instance_variable_get(:@pile)

      # The outer arrays should be different objects
      refute_same original_pile, dupped_pile

      # Each inner array should also be a different object
      original_pile.each_with_index do |entry, i|
        refute_same entry, dupped_pile[i]
      end
    end
  end

  describe "validate_value (via #add)" do
    it "raises HeaderError when value contains a newline in the middle" do
      err = assert_raises(HTTP::HeaderError) { headers.add "X-Test", "foo\nbar" }
      assert_includes err.message, "foo"
    end

    it "accepts values without newlines" do
      headers.add "X-Test", "foobar"

      assert_equal "foobar", headers["X-Test"]
    end

    it "calls .to_s on non-string values" do
      numeric_value = 42
      headers.add "X-Number", numeric_value

      assert_equal "42", headers["X-Number"]
    end

    it "raises HeaderError when .to_s result contains a newline" do
      evil = fake(to_s: "good\nevil")

      assert_raises(HTTP::HeaderError) { headers.add "X-Evil", evil }
    end

    it "includes inspected value in error message" do
      err = assert_raises(HTTP::HeaderError) { headers.add "Test", "bad\nvalue" }

      assert_includes err.message, '"bad\nvalue"'
    end
  end

  describe "#merge!" do
    before do
      headers.set :host, "example.com"
      headers.set :accept, "application/json"
      headers.merge! accept: "plain/text", cookie: %w[hoo=ray woo=hoo]
    end

    it "leaves headers not presented in other as is" do
      assert_equal "example.com", headers[:host]
    end

    it "overwrites existing values" do
      assert_equal "plain/text", headers[:accept]
    end

    it "appends other headers, not presented in base" do
      assert_equal %w[hoo=ray woo=hoo], headers[:cookie]
    end

    it "accepts an HTTP::Headers instance" do
      other = HTTP::Headers.new
      other.set :accept, "text/xml"

      h = HTTP::Headers.new
      h.set :accept, "application/json"
      h.merge!(other)

      assert_equal "text/xml", h[:accept]
    end

    it "uses set (not add) so existing values are replaced" do
      h = HTTP::Headers.new
      h.add :accept, "text/html"
      h.add :accept, "text/plain"
      h[:accept] = "application/json"

      assert_equal "application/json", h[:accept]
    end
  end

  describe "#merge" do
    let(:merged) do
      headers.merge accept: "plain/text", cookie: %w[hoo=ray woo=hoo]
    end

    before do
      headers.set :host, "example.com"
      headers.set :accept, "application/json"
    end

    it "returns an HTTP::Headers instance" do
      assert_kind_of HTTP::Headers, merged
    end

    it "is not the same object" do
      refute_same headers, merged
    end

    it "does not affects original headers" do
      refute_equal merged.to_h, headers.to_h
    end

    it "leaves headers not presented in other as is" do
      assert_equal "example.com", merged[:host]
    end

    it "overwrites existing values" do
      assert_equal "plain/text", merged[:accept]
    end

    it "appends other headers, not presented in base" do
      assert_equal %w[hoo=ray woo=hoo], merged[:cookie]
    end
  end

  describe ".coerce" do
    let(:dummy_class) { Class.new { def respond_to?(*); end } }

    it "accepts any object that respond to #to_hash" do
      hashie = fake(to_hash: { "accept" => "json" })

      assert_equal "json", HTTP::Headers.coerce(hashie)["accept"]
    end

    it "accepts any object that respond to #to_h" do
      hashie = fake(to_h: { "accept" => "json" })

      assert_equal "json", HTTP::Headers.coerce(hashie)["accept"]
    end

    it "accepts any object that respond to #to_a" do
      hashie = fake(to_a: [%w[accept json]])

      assert_equal "json", HTTP::Headers.coerce(hashie)["accept"]
    end

    it "fails if given object cannot be coerced" do
      obj = Object.new
      def obj.respond_to?(*); end
      def obj.inspect = "INSPECTED"
      def obj.to_s = "plain"

      err = assert_raises(HTTP::Error) { HTTP::Headers.coerce obj }
      assert_includes err.message, "INSPECTED"
    end

    context "with duplicate header keys (mixed case)" do
      let(:hdrs) { { "Set-Cookie" => "hoo=ray", "set_cookie" => "woo=hoo", :set_cookie => "ta=da" } }

      it "adds all headers" do
        expected = [%w[Set-Cookie hoo=ray], %w[set_cookie woo=hoo], %w[Set-Cookie ta=da]]

        assert_equal expected.sort, HTTP::Headers.coerce(hdrs).to_a.sort
      end
    end

    it "is aliased as .[]" do
      result = HTTP::Headers["Content-Type" => "text/plain"]

      assert_instance_of HTTP::Headers, result
      assert_equal "text/plain", result["Content-Type"]
    end
  end

  describe ".normalizer" do
    it "returns a Normalizer instance" do
      assert_instance_of HTTP::Headers::Normalizer, HTTP::Headers.normalizer
    end

    it "returns the same instance on subsequent calls" do
      assert_same HTTP::Headers.normalizer, HTTP::Headers.normalizer
    end
  end
end
