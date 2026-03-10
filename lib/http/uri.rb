# frozen_string_literal: true

require "addressable/uri"

module HTTP
  # Wrapper around Addressable::URI with HTTP-specific behavior
  class URI
    extend Forwardable

    # The URI given was not valid
    class InvalidError < HTTP::RequestError; end

    def_delegators :@uri, :scheme, :normalized_scheme, :scheme=
    def_delegators :@uri, :user, :normalized_user, :user=
    def_delegators :@uri, :password, :normalized_password, :password=
    def_delegators :@uri, :authority, :normalized_authority, :authority=
    def_delegators :@uri, :origin, :origin=
    def_delegators :@uri, :normalized_port, :port=
    def_delegators :@uri, :path, :normalized_path, :path=
    def_delegators :@uri, :query, :normalized_query, :query=
    def_delegators :@uri, :query_values, :query_values=
    def_delegators :@uri, :request_uri, :request_uri=
    def_delegators :@uri, :fragment, :normalized_fragment, :fragment=
    def_delegators :@uri, :omit, :join, :normalize

    # Host, either a domain name or IP address
    #
    # @example
    #   uri.host # => "example.com"
    #
    # @api public
    # @return [String] The host of the URI
    attr_reader :host

    # Normalized host
    #
    # @example
    #   uri.normalized_host # => "example.com"
    #
    # @api public
    # @return [String] The normalized host of the URI
    attr_reader :normalized_host

    # HTTP scheme string
    # @private
    HTTP_SCHEME = "http"

    # HTTPS scheme string
    # @private
    HTTPS_SCHEME = "https"

    # Pattern matching characters requiring percent-encoding
    # @private
    PERCENT_ENCODE = /[^\x21-\x7E]+/

    # Default URI normalizer
    # @private
    NORMALIZER = lambda do |uri|
      uri = HTTP::URI.parse uri

      HTTP::URI.new(
        scheme:    uri.normalized_scheme,
        authority: uri.normalized_authority,
        path:      uri.path.empty? ? "/" : percent_encode(Addressable::URI.normalize_path(uri.path)),
        query:     percent_encode(uri.query),
        fragment:  uri.normalized_fragment
      )
    end

    # Parse the given URI string, returning an HTTP::URI object
    #
    # @example
    #   HTTP::URI.parse("http://example.com/path")
    #
    # @param [HTTP::URI, String, #to_str] uri to parse
    #
    # @api public
    # @return [HTTP::URI] new URI instance
    def self.parse(uri)
      return uri if uri.is_a?(self)

      new(Addressable::URI.parse(uri))
    rescue TypeError, Addressable::URI::InvalidURIError
      raise InvalidError, "invalid URI: #{uri.inspect}"
    end

    # Encodes key/value pairs as application/x-www-form-urlencoded
    #
    # @example
    #   HTTP::URI.form_encode(foo: "bar")
    #
    # @param [#to_hash, #to_ary] form_values to encode
    # @param [TrueClass, FalseClass] sort should key/value pairs be sorted first?
    #
    # @api public
    # @return [String] encoded value
    def self.form_encode(form_values, sort: false)
      Addressable::URI.form_encode(form_values, sort)
    end

    # Percent-encode matching characters in a string
    #
    # @param [String] string raw string
    #
    # @api private
    # @return [String] encoded value
    def self.percent_encode(string)
      string&.gsub(PERCENT_ENCODE) do |substr|
        substr.bytes.map { |c| format("%%%02X", c) }.join
      end
    end

    # Creates an HTTP::URI instance from the given options
    #
    # @example
    #   HTTP::URI.new(scheme: "http", host: "example.com")
    #
    # @param [Hash, Addressable::URI] options_or_uri
    #
    # @option options_or_uri [String, #to_str] :scheme URI scheme
    # @option options_or_uri [String, #to_str] :user for basic authentication
    # @option options_or_uri [String, #to_str] :password for basic authentication
    # @option options_or_uri [String, #to_str] :host name component
    # @option options_or_uri [String, #to_str] :port network port to connect to
    # @option options_or_uri [String, #to_str] :path component to request
    # @option options_or_uri [String, #to_str] :query component distinct from path
    # @option options_or_uri [String, #to_str] :fragment component at the end of the URI
    #
    # @api public
    # @return [HTTP::URI] new URI instance
    def initialize(options_or_uri = {})
      case options_or_uri
      when Hash
        @uri = Addressable::URI.new(options_or_uri)
      when Addressable::URI
        @uri = options_or_uri
      else
        raise TypeError, "expected Hash for options, got #{options_or_uri.class}"
      end

      @host = process_ipv6_brackets(@uri.host)
      @normalized_host = process_ipv6_brackets(@uri.normalized_host)
    end

    # Are these URI objects equal after normalization
    #
    # @example
    #   HTTP::URI.parse("http://example.com") == HTTP::URI.parse("http://example.com")
    #
    # @param [Object] other URI to compare this one with
    #
    # @api public
    # @return [TrueClass, FalseClass] are the URIs equivalent (after normalization)?
    def ==(other)
      other.is_a?(URI) && String(normalize) == String(other.normalize)
    end

    # Are these URI objects equal without normalization
    #
    # @example
    #   uri = HTTP::URI.parse("http://example.com")
    #   uri.eql?(HTTP::URI.parse("http://example.com"))
    #
    # @param [Object] other URI to compare this one with
    #
    # @api public
    # @return [TrueClass, FalseClass] are the URIs equivalent?
    def eql?(other)
      other.is_a?(URI) && String(self) == String(other)
    end

    # Hash value based off the normalized form of a URI
    #
    # @example
    #   HTTP::URI.parse("http://example.com").hash
    #
    # @api public
    # @return [Integer] A hash of the URI
    def hash
      @hash ||= [self.class, String(self)].hash
    end

    # Sets the host component for the URI
    #
    # @example
    #   uri = HTTP::URI.parse("http://example.com")
    #   uri.host = "other.com"
    #
    # @param [String, #to_str] new_host The new host component
    # @api public
    # @return [void]
    def host=(new_host)
      @uri.host = process_ipv6_brackets(new_host, brackets: true)

      @host = process_ipv6_brackets(@uri.host)
      @normalized_host = process_ipv6_brackets(@uri.normalized_host)
    end

    # Port number, either as specified or the default
    #
    # @example
    #   HTTP::URI.parse("http://example.com").port
    #
    # @api public
    # @return [Integer] port number
    def port
      @uri.port || @uri.default_port
    end

    # Checks whether the URI scheme is HTTP
    #
    # @example
    #   HTTP::URI.parse("http://example.com").http?
    #
    # @api public
    # @return [True] if URI is HTTP
    # @return [False] otherwise
    def http?
      HTTP_SCHEME == scheme
    end

    # Checks whether the URI scheme is HTTPS
    #
    # @example
    #   HTTP::URI.parse("https://example.com").https?
    #
    # @api public
    # @return [True] if URI is HTTPS
    # @return [False] otherwise
    def https?
      HTTPS_SCHEME == scheme
    end

    # Duplicates the URI object
    #
    # @example
    #   HTTP::URI.parse("http://example.com").dup
    #
    # @api public
    # @return [HTTP::URI] duplicated URI
    def dup
      self.class.new @uri.dup
    end

    # Convert an HTTP::URI to a String
    #
    # @example
    #   HTTP::URI.parse("http://example.com").to_s
    #
    # @api public
    # @return [String] URI serialized as a String
    def to_s
      String(@uri)
    end
    alias to_str to_s

    # Returns human-readable representation of URI
    #
    # @example
    #   HTTP::URI.parse("http://example.com").inspect
    #
    # @api public
    # @return [String] human-readable representation of URI
    def inspect
      format("#<%s:0x%014x URI:%s>", self.class, object_id << 1, self)
    end

    # Pattern matching interface
    #
    # @example
    #   uri.deconstruct_keys(%i[scheme host])
    #
    # @param keys [Array<Symbol>, nil] keys to extract, or nil for all
    # @return [Hash{Symbol => Object}]
    # @api public
    def deconstruct_keys(keys)
      hash = { scheme: scheme, host: host, port: port, path: path,
               query: query, fragment: fragment, user: user, password: password }
      keys ? hash.slice(*keys) : hash
    end

    private

    # Adds or removes IPv6 brackets from a host
    #
    # @param [String] raw_host
    # @param [Boolean] brackets
    # @api private
    # @return [String] Host with IPv6 address brackets added or removed
    def process_ipv6_brackets(raw_host, brackets: false)
      ip = IPAddr.new(raw_host)

      if ip.ipv6?
        brackets ? "[#{ip}]" : ip.to_s
      else
        raw_host
      end
    rescue IPAddr::Error
      raw_host
    end
  end
end
