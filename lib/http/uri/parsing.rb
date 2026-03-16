# frozen_string_literal: true

module HTTP
  # Class methods and private helpers for URI parsing and host processing
  class URI
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
      raise InvalidError, "invalid URI: nil" if uri.nil?

      uri_string = begin
        String(uri)
      rescue TypeError, NoMethodError
        raise InvalidError, "invalid URI: #{uri.inspect}"
      end
      new(**parse_components(uri_string))
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
      return ::URI.encode_www_form(form_values) unless sort

      ::URI.encode_www_form(form_values.sort_by { |k, _| String(k) })
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

    # Loads the addressable gem on first use
    #
    # @api private
    # @return [void]
    # @raise [LoadError] if addressable gem is not installed
    def self.require_addressable
      return if defined?(@addressable_loaded)

      require "addressable/uri"
      @addressable_loaded = true
    end

    # Convert a hostname to ASCII via IDNA (requires addressable)
    #
    # @param [String] host hostname to encode
    # @api private
    # @return [String] ASCII-encoded hostname
    def self.idna_to_ascii(host)
      return host if host.ascii_only?

      require_addressable
      Addressable::IDNA.to_ascii(host) # steep:ignore
    end

    private

    # Serialize the authority section of a URI (userinfo + host + port)
    #
    # @api private
    # @return [String] authority component
    def authority_string
      str = +"//"
      if (user = @user)
        str << user
        str << ":#{@password}" if @password
        str << "@"
      end
      str << @raw_host # steep:ignore
      str << ":#{@port}" if @port
      str
    end

    # Adds or removes IPv6 brackets from a host
    #
    # @param [String] raw_host
    # @param [Boolean] brackets
    # @api private
    # @return [String] Host with IPv6 address brackets added or removed
    def process_ipv6_brackets(raw_host, brackets: false)
      return unless raw_host

      stripped = raw_host.delete_prefix("[").delete_suffix("]")
      ip = IPAddr.new(stripped)

      if ip.ipv6?
        brackets ? "[#{ip}]" : ip.to_s
      else
        raw_host
      end
    rescue IPAddr::Error
      raw_host
    end

    # Normalize a host for comparison and lookup
    #
    # Percent-decodes, strips trailing dot, lowercases, and IDN-encodes
    # non-ASCII hostnames.
    #
    # @param [String, nil] host the host to normalize
    # @api private
    # @return [String, nil] normalized host
    def normalize_host(host)
      return nil unless host

      h = host.gsub(/%\h{2}/) { |match| match.delete_prefix("%").to_i(16).chr }
      h = h.delete_suffix(".")
      h = h.downcase
      self.class.idna_to_ascii(h)
    end

    # Parse a URI string into component parts
    #
    # Uses stdlib for printable-ASCII URIs (faster), falling back to
    # Addressable for non-ASCII or when stdlib rejects the input.
    #
    # @param [String] uri_string the URI to parse
    # @api private
    # @return [Hash] URI components
    private_class_method def self.parse_components(uri_string)
      return parse_with_addressable(uri_string) if uri_string.match?(NEEDS_ADDRESSABLE)

      parse_with_stdlib(uri_string) || parse_with_addressable(uri_string)
    end

    # Parse an ASCII URI using stdlib
    #
    # @param [String] uri_string the URI to parse
    # @api private
    # @return [Hash, nil] URI components, or nil if stdlib rejects the input
    private_class_method def self.parse_with_stdlib(uri_string)
      parsed = ::URI.parse(uri_string)
      # stdlib always returns a port (defaulting to scheme's default);
      # only store it when explicitly specified
      port = parsed.port
      port = nil if port.eql?(parsed.default_port)
      { scheme: parsed.scheme, user: parsed.user, password: parsed.password,
        host: parsed.host, port: port, path: parsed.path,
        query: parsed.query, fragment: parsed.fragment }
    rescue ::URI::InvalidURIError
      nil
    end

    # Parse a non-ASCII URI using Addressable
    #
    # @param [String] uri_string the URI to parse
    # @api private
    # @return [Hash] URI components
    private_class_method def self.parse_with_addressable(uri_string)
      require_addressable
      parsed = Addressable::URI.parse(uri_string) # steep:ignore
      { scheme: parsed.scheme, user: parsed.user, password: parsed.password,
        host: parsed.host, port: parsed.port, path: parsed.path,
        query: parsed.query, fragment: parsed.fragment }
    rescue Addressable::URI::InvalidURIError # steep:ignore
      raise InvalidError, "invalid URI: #{uri_string.inspect}"
    end
  end
end
