# frozen_string_literal: true

require "uri"

module HTTP
  # HTTP URI with scheme, authority, path, query, and fragment components
  #
  # Stores URI components as instance variables. Addressable is only used
  # when parsing non-ASCII (IRI) strings; ASCII URIs use stdlib's URI.parse.
  class URI
    # The URI given was not valid
    class InvalidError < HTTP::RequestError; end

    # URI scheme (e.g. "http", "https")
    #
    # @example
    #   uri.scheme # => "http"
    #
    # @api public
    # @return [String, nil] The URI scheme
    attr_reader :scheme

    # User component for authentication
    #
    # @example
    #   uri.user # => "admin"
    #
    # @api public
    # @return [String, nil] The user component
    attr_reader :user

    # Password component for authentication
    #
    # @example
    #   uri.password # => "secret"
    #
    # @api public
    # @return [String, nil] The password component
    attr_reader :password

    # Host, either a domain name or IP address
    #
    # @example
    #   uri.host # => "example.com"
    #
    # @api public
    # @return [String, nil] The host of the URI
    attr_reader :host

    # Normalized host
    #
    # @example
    #   uri.normalized_host # => "example.com"
    #
    # @api public
    # @return [String, nil] The normalized host of the URI
    attr_reader :normalized_host

    # URI path component
    #
    # @example
    #   uri.path # => "/foo"
    #
    # @api public
    # @return [String] The path component
    attr_accessor :path

    # URI query string
    #
    # @example
    #   uri.query # => "q=1"
    #
    # @api public
    # @return [String, nil] The query component
    attr_accessor :query

    # URI fragment
    #
    # @example
    #   uri.fragment # => "section1"
    #
    # @api public
    # @return [String, nil] The fragment component
    attr_reader :fragment

    # HTTP scheme string
    # @private
    HTTP_SCHEME = "http"

    # HTTPS scheme string
    # @private
    HTTPS_SCHEME = "https"

    # Pattern matching characters requiring percent-encoding
    # @private
    PERCENT_ENCODE = /[^\x21-\x7E]+/

    # Default ports for supported URI schemes
    # @private
    DEFAULT_PORTS = {
      "http"  => 80,
      "https" => 443,
      "ws"    => 80,
      "wss"   => 443
    }.freeze

    # Pattern for characters that stdlib's URI.parse silently modifies
    # @private
    NEEDS_ADDRESSABLE = /[^\x20-\x7E]/

    # Creates an HTTP::URI instance from the given keyword arguments
    #
    # @example
    #   HTTP::URI.new(scheme: "http", host: "example.com")
    #
    # @param [String, nil] scheme URI scheme
    # @param [String, nil] user for basic authentication
    # @param [String, nil] password for basic authentication
    # @param [String, nil] host name component (IPv6 addresses must be bracketed)
    # @param [Integer, nil] port network port to connect to
    # @param [String, nil] path component to request
    # @param [String, nil] query component distinct from path
    # @param [String, nil] fragment component at the end of the URI
    #
    # @api public
    # @return [HTTP::URI] new URI instance
    def initialize(scheme: nil, user: nil, password: nil, host: nil,
                   port: nil, path: nil, query: nil, fragment: nil)
      @scheme   = scheme
      @user     = user
      @password = password
      @raw_host = host
      @host     = process_ipv6_brackets(host)
      @normalized_host = normalize_host(@host)
      @port     = port
      @path     = path || ""
      @query    = query
      @fragment = fragment
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
      other.is_a?(URI) && String(normalize).eql?(String(other.normalize))
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
      other.is_a?(URI) && String(self).eql?(String(other))
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
      @raw_host = process_ipv6_brackets(new_host, brackets: true)
      @host = process_ipv6_brackets(@raw_host)
      @normalized_host = normalize_host(@host)
    end

    # Port number, either as specified or the default
    #
    # @example
    #   HTTP::URI.parse("http://example.com").port
    #
    # @api public
    # @return [Integer, nil] port number
    def port
      @port || default_port
    end

    # Default port for the URI scheme
    #
    # @example
    #   HTTP::URI.parse("http://example.com").default_port # => 80
    #
    # @api public
    # @return [Integer, nil] default port or nil for unknown schemes
    def default_port
      DEFAULT_PORTS[@scheme&.downcase]
    end

    # The origin (scheme + host + port) per RFC 6454
    #
    # @example
    #   HTTP::URI.parse("http://example.com").origin # => "http://example.com"
    #
    # @api public
    # @return [String] origin of the URI
    def origin
      port_suffix = ":#{port}" unless port.eql?(default_port)
      "#{String(@scheme).downcase}://#{String(@raw_host).downcase}#{port_suffix}"
    end

    # The path and query for use in an HTTP request line
    #
    # @example
    #   HTTP::URI.parse("http://example.com/path?q=1").request_uri # => "/path?q=1"
    #
    # @api public
    # @return [String] request URI string
    def request_uri
      "#{'/' if @path.empty?}#{@path}#{"?#{@query}" if @query}"
    end

    # Returns a new URI with the specified components removed
    #
    # @example
    #   HTTP::URI.parse("http://example.com#frag").omit(:fragment)
    #
    # @param components [Symbol] URI components to remove
    # @api public
    # @return [HTTP::URI] new URI without the specified components
    def omit(*components)
      self.class.new(
        **{ scheme: @scheme, user: @user, password: @password, host: @raw_host,
            port: @port, path: @path, query: @query, fragment: @fragment }.except(*components)
      )
    end

    # Resolves another URI against this one per RFC 3986
    #
    # @example
    #   HTTP::URI.parse("http://example.com/foo/").join("bar")
    #
    # @param [String, URI] other the URI to resolve
    #
    # @api public
    # @return [HTTP::URI] resolved URI
    def join(other)
      base = self.class.percent_encode(String(self))
      ref  = self.class.percent_encode(String(other))
      self.class.parse(::URI.join(base, ref))
    end

    # Returns a normalized copy of the URI
    #
    # Lowercases scheme and host, strips default port. Used by {#==}
    # to compare URIs for equivalence.
    #
    # @example
    #   HTTP::URI.parse("HTTP://EXAMPLE.COM:80").normalize
    #
    # @api public
    # @return [HTTP::URI] normalized URI
    def normalize
      self.class.new(
        scheme:   @scheme&.downcase,
        user:     @user,
        password: @password,
        host:     @raw_host&.downcase,
        port:     (@port unless port.eql?(default_port)),
        path:     @path.empty? && @raw_host ? "/" : @path,
        query:    @query,
        fragment: @fragment
      )
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
      HTTP_SCHEME.eql?(@scheme)
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
      HTTPS_SCHEME.eql?(@scheme)
    end

    # Duplicates the URI object
    #
    # @example
    #   HTTP::URI.parse("http://example.com").dup
    #
    # @api public
    # @return [HTTP::URI] duplicated URI
    def dup
      self.class.new(
        scheme: @scheme, user: @user, password: @password, host: @raw_host,
        port: @port, path: @path, query: @query, fragment: @fragment
      )
    end

    # Convert an HTTP::URI to a String
    #
    # @example
    #   HTTP::URI.parse("http://example.com").to_s
    #
    # @api public
    # @return [String] URI serialized as a String
    def to_s
      str = +""
      str << "#{@scheme}:" if @scheme
      str << authority_string if @raw_host
      str << @path
      str << "?#{@query}" if @query
      str << "##{@fragment}" if @fragment
      str
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
      hash = { scheme: @scheme, host: @host, port: port, path: @path,
               query: @query, fragment: @fragment, user: @user, password: @password }
      keys ? hash.slice(*keys) : hash
    end
  end
end

require "http/uri/parsing"
require "http/uri/normalizer"
