# frozen_string_literal: true

require "securerandom"

require "http/form_data/multipart/param"
require "http/form_data/readable"
require "http/form_data/composite_io"

module HTTP
  module FormData
    # `multipart/form-data` form data.
    class Multipart
      include Readable

      # Default MIME type for multipart form data
      DEFAULT_CONTENT_TYPE = "multipart/form-data"

      # Returns the multipart boundary string
      #
      # @example
      #   multipart.boundary # => "-----abc123"
      #
      # @api public
      # @return [String]
      attr_reader :boundary

      # Creates a new Multipart form data instance
      #
      # @example Basic form data
      #   Multipart.new({ foo: "bar" })
      #
      # @example With custom content type
      #   Multipart.new(parts, content_type: "multipart/related")
      #
      # @api public
      # @param [Enumerable, Hash, #to_h] data form data key-value pairs
      # @param [String] boundary custom boundary string
      # @param [String] content_type MIME type for the Content-Type header
      def initialize(data, boundary: self.class.generate_boundary, content_type: DEFAULT_CONTENT_TYPE)
        @boundary     = boundary.to_s.freeze
        @content_type = content_type
        @io = CompositeIO.new(parts(data).flat_map { |part| [glue, part] } << tail)
      end

      # Generates a boundary string for multipart form data
      #
      # @example
      #   Multipart.generate_boundary # => "-----abc123..."
      #
      # @api public
      # @return [String]
      def self.generate_boundary
        ("-" * 21) << SecureRandom.hex(21)
      end

      # Returns MIME type for the Content-Type header
      #
      # @example
      #   multipart.content_type
      #   # => "multipart/form-data; boundary=-----abc123"
      #
      # @api public
      # @return [String]
      def content_type
        "#{@content_type}; boundary=#{@boundary}"
      end

      # Returns form data content size for Content-Length
      #
      # @example
      #   multipart.content_length # => 123
      #
      # @api public
      # @return [Integer]
      alias content_length size

      private

      # Returns the boundary glue between parts
      #
      # @api private
      # @return [String]
      def glue
        @glue ||= "--#{@boundary}#{CRLF}"
      end

      # Returns the closing boundary tail
      #
      # @api private
      # @return [String]
      def tail
        @tail ||= "--#{@boundary}--#{CRLF}"
      end

      # Coerces data into an array of Param objects
      #
      # @api private
      # @return [Array<Param>]
      def parts(data)
        FormData.ensure_data(data).flat_map do |name, values|
          Array(values).map { |value| Param.new(name, value) }
        end
      end
    end
  end
end
