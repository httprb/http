# frozen_string_literal: true

require "forwardable"

require "http/errors"
require "http/headers/mixin"
require "http/headers/normalizer"
require "http/headers/known"

module HTTP
  # HTTP Headers container.
  class Headers
    extend Forwardable
    include Enumerable

    class << self
      # Coerces given object into Headers
      #
      # @example
      #   headers = HTTP::Headers.coerce("Content-Type" => "text/plain")
      #
      # @raise [Error] if object can't be coerced
      # @param [#to_hash, #to_h, #to_a] object
      # @return [Headers]
      # @api public
      def coerce(object)
        object = if    object.respond_to?(:to_hash) then object.to_hash
                 elsif object.respond_to?(:to_h)    then object.to_h
                 elsif object.respond_to?(:to_a)    then object.to_a
                 else raise Error, "Can't coerce #{object.inspect} to Headers"
                 end

        headers = new
        object.each { |k, v| headers.add k, v }
        headers
      end
      # @!method [](object)
      #   Coerces given object into Headers
      #
      #   @example
      #     headers = HTTP::Headers["Content-Type" => "text/plain"]
      #
      #   @see .coerce
      #   @return [Headers]
      #   @api public
      alias [] coerce

      # Returns the shared normalizer instance
      #
      # @example
      #   HTTP::Headers.normalizer
      #
      # @return [Headers::Normalizer]
      # @api public
      def normalizer
        @normalizer ||= Normalizer.new #: Headers::Normalizer
      end
    end

    # Creates a new empty headers container
    #
    # @example
    #   headers = HTTP::Headers.new
    #
    # @return [Headers]
    # @api public
    def initialize
      # The @pile stores each header value using a three element array:
      #  0 - the normalized header key, used for lookup
      #  1 - the header key as it will be sent with a request
      #  2 - the value
      @pile = []
    end

    # Sets header, replacing any existing values
    #
    # @example
    #   headers.set("Content-Type", "text/plain")
    #
    # @param (see #add)
    # @return [void]
    # @api public
    def set(name, value)
      delete(name)
      add(name, value)
    end
    # @!method []=(name, value)
    #   Sets header, replacing any existing values
    #
    #   @example
    #     headers["Content-Type"] = "text/plain"
    #
    #   @see #set
    #   @return [void]
    #   @api public
    alias []= set

    # Removes header with the given name
    #
    # @example
    #   headers.delete("Content-Type")
    #
    # @param [#to_s] name header name
    # @return [void]
    # @api public
    def delete(name)
      name = normalize_header name
      @pile.delete_if { |k, _| k == name }
    end

    # Appends header value(s) to the given name
    #
    # @example
    #   headers.add("Accept", "text/html")
    #
    # @param [String, Symbol] name header name. When specified as a string, the
    #   name is sent as-is. When specified as a symbol, the name is converted
    #   to a string of capitalized words separated by a dash. Word boundaries
    #   are determined by an underscore (`_`) or a dash (`-`).
    #   Ex: `:content_type` is sent as `"Content-Type"`, and `"auth_key"` (string)
    #   is sent as `"auth_key"`.
    # @param [Array<#to_s>, #to_s] value header value(s) to be appended
    # @return [void]
    # @api public
    def add(name, value)
      lookup_name = normalize_header(name)
      wire_name = wire_name_for(name, lookup_name)

      Array(value).each do |v|
        @pile << [
          lookup_name,
          wire_name,
          validate_value(v)
        ]
      end
    end

    # Returns list of header values if any
    #
    # @example
    #   headers.get("Content-Type")
    #
    # @return [Array<String>]
    # @api public
    def get(name)
      name = normalize_header name
      @pile.select { |k, _| k == name }.map { |_, _, v| v }
    end

    # Smart version of {#get}
    #
    # @example
    #   headers["Content-Type"]
    #
    # @return [nil] if header was not set
    # @return [String] if header has exactly one value
    # @return [Array<String>] if header has more than one value
    # @api public
    def [](name)
      values = get(name)
      return if values.empty?

      values.one? ? values.first : values
    end

    # Tells whether header with given name is set
    #
    # @example
    #   headers.include?("Content-Type")
    #
    # @return [Boolean]
    # @api public
    def include?(name)
      name = normalize_header name
      @pile.any? { |k, _| k == name }
    end

    # Returns Rack-compatible headers Hash
    #
    # @example
    #   headers.to_h
    #
    # @return [Hash]
    # @api public
    def to_h
      keys.to_h { |k| [k, self[k]] }
    end
    # @!method to_hash
    #   Returns Rack-compatible headers Hash
    #
    #   @example
    #     headers.to_hash
    #
    #   @see #to_h
    #   @return [Hash]
    #   @api public
    alias to_hash to_h

    # Returns human-readable representation of self instance
    #
    # @example
    #   headers.inspect
    #
    # @return [String]
    # @api public
    def inspect
      "#<#{self.class}>"
    end

    # Returns list of header names
    #
    # @example
    #   headers.keys
    #
    # @return [Array<String>]
    # @api public
    def keys
      @pile.map { |_, k, _| k }.uniq
    end

    # Compares headers to another Headers or Array of pairs
    #
    # @example
    #   headers == other_headers
    #
    # @return [Boolean]
    # @api public
    def ==(other)
      return false unless other.respond_to? :to_a

      to_a == other.to_a
    end

    # Calls the given block once for each key/value pair
    #
    # @example
    #   headers.each { |name, value| puts "#{name}: #{value}" }
    #
    # @return [Enumerator] if no block given
    # @return [Headers] self-reference
    # @api public
    def each
      return to_enum unless block_given?

      @pile.each { |item| yield(item.drop(1)) }
      self
    end

    # @!method empty?
    #   Returns true if self has no key/value pairs
    #
    #   @example
    #     headers.empty?
    #
    #   @return [Boolean]
    #   @api public
    def_delegator :@pile, :empty?

    # @!method hash
    #   Computes a hash-code for this headers container
    #
    #   @example
    #     headers.hash
    #
    #   @see http://www.ruby-doc.org/core/Object.html#method-i-hash
    #   @return [Fixnum]
    #   @api public
    def_delegator :@pile, :hash

    # Properly clones internal key/value storage
    #
    # @return [void]
    # @api private
    def initialize_copy(_orig)
      @pile = @pile.map(&:dup)
    end

    # Merges other headers into self
    #
    # @example
    #   headers.merge!("Accept" => "text/html")
    #
    # @see #merge
    # @return [void]
    # @api public
    def merge!(other)
      coerced = self.class.coerce(other)
      names = coerced.keys
      names.each { |name| set name, coerced.get(name) }
    end

    # Returns new instance with other headers merged in
    #
    # @example
    #   new_headers = headers.merge("Accept" => "text/html")
    #
    # @see #merge!
    # @return [Headers]
    # @api public
    def merge(other)
      dup.tap { |dupped| dupped.merge! other }
    end

    private

    # Returns the wire name for a header
    #
    # @return [String]
    # @api private
    def wire_name_for(name, lookup_name)
      case name
      when String then name
      when Symbol then lookup_name
      else raise HeaderError, "HTTP header must be a String or Symbol: #{name.inspect}"
      end
    end

    # Transforms name to canonical HTTP header capitalization
    #
    # @return [String]
    # @api private
    def normalize_header(name)
      self.class.normalizer.call(name)
    end

    # Ensures there is no new line character in the header value
    #
    # @param [String] value
    # @raise [HeaderError] if value includes new line character
    # @return [String] stringified header value
    # @api private
    def validate_value(value)
      v = value.to_s
      return v unless v.include?("\n")

      raise HeaderError, "Invalid HTTP header field value: #{v.inspect}"
    end
  end
end
