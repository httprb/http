require 'forwardable'

require 'http/headers/mixin'

module HTTP
  class Headers
    extend Forwardable
    include Enumerable

    # Matches HTTP header names when in "Canonical-Http-Format"
    CANONICAL_HEADER = /^[A-Z][a-z]*(-[A-Z][a-z]*)*$/

    # :nodoc:
    def initialize
      @pile = []
    end

    # Sets header
    #
    # @return [void]
    def set(name, value)
      delete(name)
      add(name, value)
    end
    alias_method :[]=, :set

    # Removes header
    #
    # @return [void]
    def delete(name)
      name = canonicalize_header name.to_s
      @pile.delete_if { |k, _| k == name }
    end

    # Append header
    #
    # @return [void]
    def add(name, value)
      name = canonicalize_header name.to_s
      Array(value).each { |v| @pile << [name, v] }
    end
    alias_method :append, :add

    # Return array of header values if any.
    #
    # @return [Array]
    def get(name)
      name = canonicalize_header name.to_s
      @pile.select { |k, _| k == name }.map { |_, v| v }
    end

    # Smart version of {#get}
    #
    # @return [NilClass] if header was not set
    # @return [Object] if header has exactly one value
    # @return [Array<Object>] if header has more than one value
    def [](name)
      values = get(name)

      case values.count
      when 0 then nil
      when 1 then values.first
      else        values
      end
    end

    # Converts headers into a Rack-compatible Hash
    #
    # @return [Hash]
    def to_h
      Hash[keys.map { |k| [k, self[k]] }]
    end

    # Array of key/value pairs
    #
    # @return [Array<[String, String]>]
    def to_a
      @pile.map { |pair| pair.map(&:dup) }
    end

    # :nodoc:
    def inspect
      "#<#{self.class} #{to_h.inspect}>"
    end

    # List of header names
    #
    # @return [Array<String>]
    def keys
      @pile.map { |k, _| k }.uniq
    end

    # Compares headers to another Headers or Array of key/value pairs
    #
    # @return [Boolean]
    def ==(other)
      return false unless other.respond_to? :to_a
      @pile == other.to_a
    end

    def_delegators :@pile, :each, :empty?, :hash

    # :nodoc:
    def initialize_copy(orig)
      super
      @pile = to_a
    end

    # Merge in `other` headers
    #
    # @see #merge
    # @return [void]
    def merge!(other)
      self.class.coerce(other).to_h.each { |name, values| set name, values }
    end

    # Returns new Headers instance with `other` headers merged in.
    #
    # @see #merge!
    # @return [Headers]
    def merge(other)
      dup.tap { |dupped| dupped.merge! other }
    end

    # Initiates new Headers object from given object.
    #
    # @raise [Error] if given object can't be coerced
    # @param [#to_hash, #to_h, #to_a] object
    # @return [Headers]
    def self.coerce(object)
      unless object.is_a? self
        object = case
                when object.respond_to?(:to_hash) then object.to_hash
                when object.respond_to?(:to_h)    then object.to_h
                when object.respond_to?(:to_a)    then object.to_a
                else fail Error, "Can't coerce #{object.inspect} to Headers"
                end
      end

      headers = new
      object.each { |k, v| headers.add k, v }
      headers
    end

  private

    # Transform to canonical HTTP header capitalization
    # @param [String] name
    # @return [String]
    def canonicalize_header(name)
      name[CANONICAL_HEADER] || name.split(/[\-_]/).map(&:capitalize).join('-')
    end
  end
end
