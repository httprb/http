# frozen_string_literal: true

require "http/form_data/readable"

require "uri"
require "stringio"

module HTTP
  module FormData
    # `application/x-www-form-urlencoded` form data.
    class Urlencoded
      include Readable

      class << self
        # Sets custom form data encoder implementation
        #
        # @example
        #
        #     module CustomFormDataEncoder
        #       UNESCAPED_CHARS = /[^a-z0-9\-\.\_\~]/i
        #
        #       def self.escape(s)
        #         ::URI::DEFAULT_PARSER.escape(s.to_s, UNESCAPED_CHARS)
        #       end
        #
        #       def self.call(data)
        #         parts = []
        #
        #         data.each do |k, v|
        #           k = escape(k)
        #
        #           if v.nil?
        #             parts << k
        #           elsif v.respond_to?(:to_ary)
        #             v.to_ary.each { |vv| parts << "#{k}=#{escape vv}" }
        #           else
        #             parts << "#{k}=#{escape v}"
        #           end
        #         end
        #
        #         parts.join("&")
        #       end
        #     end
        #
        #     HTTP::FormData::Urlencoded.encoder = CustomFormDataEncoder
        #
        # @api public
        # @raise [ArgumentError] if implementation does not respond to `#call`
        # @param implementation [#call]
        # @return [void]
        def encoder=(implementation)
          raise ArgumentError unless implementation.respond_to? :call

          @encoder = implementation
        end

        # Returns form data encoder implementation
        #
        # @example
        #   Urlencoded.encoder # => #<Method: DefaultEncoder.encode>
        #
        # @api public
        # @see .encoder=
        # @return [#call]
        def encoder
          @encoder || DefaultEncoder
        end

        # Default encoder for urlencoded form data
        module DefaultEncoder
          class << self
            # Recursively encodes form data value
            #
            # @example
            #   DefaultEncoder.encode({ foo: "bar" }) # => "foo=bar"
            #
            # @api public
            # @param [Hash, Array, String, nil] value
            # @param [String, nil] prefix
            # @return [String]
            def encode(value, prefix = nil)
              case value
              when Hash  then encode_hash(value, prefix)
              when Array then encode_array(value, prefix)
              when nil   then prefix.to_s
              else
                raise ArgumentError, "value must be a Hash" if prefix.nil?

                "#{prefix}=#{escape(value)}"
              end
            end

            alias call encode

            private

            # Encodes an Array value
            #
            # @api private
            # @return [String]
            def encode_array(value, prefix)
              if prefix
                value.map { |v| encode(v, "#{prefix}[]") }.join("&")
              else
                encode_pairs(value)
              end
            end

            # Encodes an Array of key-value pairs
            #
            # @api private
            # @return [String]
            def encode_pairs(pairs)
              pairs.map { |k, v| encode(v, escape(k)) }.reject(&:empty?).join("&")
            end

            # Encodes a Hash value
            #
            # @api private
            # @return [String]
            def encode_hash(hash, prefix)
              hash.map do |k, v|
                encode(v, prefix ? "#{prefix}[#{escape(k)}]" : escape(k))
              end.reject(&:empty?).join("&")
            end

            # URL-encodes a value
            #
            # @api private
            # @return [String]
            def escape(value)
              ::URI.encode_www_form_component(value)
            end
          end
        end

        private_constant :DefaultEncoder
      end

      # Creates a new Urlencoded form data instance
      #
      # @example
      #   Urlencoded.new({ "foo" => "bar" })
      #
      # @api public
      # @param [Enumerable, Hash, #to_h] data form data key-value pairs
      # @param [#call] encoder custom encoder implementation
      def initialize(data, encoder: nil)
        encoder ||= self.class.encoder
        @io = StringIO.new(encoder.call(FormData.ensure_data(data)))
      end

      # Returns MIME type for the Content-Type header
      #
      # @example
      #   urlencoded.content_type
      #   # => "application/x-www-form-urlencoded"
      #
      # @api public
      # @return [String]
      def content_type
        "application/x-www-form-urlencoded"
      end

      # Returns form data content size for Content-Length
      #
      # @example
      #   urlencoded.content_length # => 17
      #
      # @api public
      # @return [Integer]
      alias content_length size
    end
  end
end
