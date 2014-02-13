require 'forwardable'
require 'delegate'

module HTTP
  # Headers Hash wraper with keys normalization
  class Headers < ::Delegator
    module Mixin
      extend Forwardable
      attr_reader :headers
      def_delegators :headers, :[], :[]=
    end

    # Matches HTTP header names when in "Canonical-Http-Format"
    CANONICAL_HEADER = /^[A-Z][a-z]*(-[A-Z][a-z]*)*$/

    def initialize(obj = {})
      super({})
      __setobj__ obj
    end

    # Transform to canonical HTTP header capitalization
    def canonicalize_header(header)
      header.to_s.split(/[\-_]/).map(&:capitalize).join('-')
    end

    # Obtain the given header
    def [](name)
      super(name) || super(canonicalize_header name)
    end

    # Set a header
    def []=(name, value)
      # If we have a canonical header, we're done, canonicalize otherwise
      name = name.to_s[CANONICAL_HEADER] || canonicalize_header(name)

      # Check if the header has already been set and group
      value = Array(self[name]) + Array(value) if key? name

      super name, value
    end

  protected

    # :nodoc:
    def __getobj__
      @headers
    end

    # :nodoc:
    def __setobj__(obj)
      @headers = {}
      obj.each { |k, v| self[k] = v } if obj.respond_to? :each
    end
  end
end
