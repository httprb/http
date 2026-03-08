# frozen_string_literal: true

require "tempfile"
require "zlib"

require "http/request/body"

module HTTP
  module Features
    # Automatically compresses request bodies with gzip or deflate
    class AutoDeflate < Feature
      # Supported compression methods
      VALID_METHODS = Set.new(%w[gzip deflate]).freeze

      # Compression method name
      #
      # @example
      #   feature.method # => "gzip"
      #
      # @return [String] compression method name
      # @api public
      attr_reader :method

      # Initializes the AutoDeflate feature
      #
      # @example
      #   AutoDeflate.new(method: "gzip")
      #
      # @param method [String] compression method ("gzip" or "deflate")
      # @return [AutoDeflate]
      # @api public
      def initialize(method: "gzip")
        super()

        @method = method.to_s

        raise Error, "Only gzip and deflate methods are supported" unless VALID_METHODS.include?(@method)
      end

      # Wraps a request with compressed body
      #
      # @example
      #   feature.wrap_request(request)
      #
      # @param request [HTTP::Request]
      # @return [HTTP::Request]
      # @api public
      def wrap_request(request)
        return request unless method
        return request if request.body.empty?

        # We need to delete Content-Length header. It will be set automatically by HTTP::Request::Writer
        request.headers.delete(Headers::CONTENT_LENGTH)
        request.headers[Headers::CONTENT_ENCODING] = method

        build_deflated_request(request)
      end

      # Returns a compressed body for the given body
      #
      # @example
      #   feature.deflated_body(body)
      #
      # @param body [HTTP::Request::Body]
      # @return [GzippedBody, DeflatedBody, nil]
      # @api public
      def deflated_body(body)
        case method
        when "gzip"
          GzippedBody.new(body)
        when "deflate"
          DeflatedBody.new(body)
        end
      end

      private

      # Build a new request with deflated body
      # @return [HTTP::Request]
      # @api private
      def build_deflated_request(request)
        Request.new(
          version:        request.version,
          verb:           request.verb,
          uri:            request.uri,
          headers:        request.headers,
          proxy:          request.proxy,
          body:           deflated_body(request.body),
          uri_normalizer: request.uri_normalizer
        )
      end

      HTTP::Options.register_feature(:auto_deflate, self)

      # Base class for compressed request body wrappers
      class CompressedBody < HTTP::Request::Body
        # Initializes a compressed body wrapper
        #
        # @example
        #   CompressedBody.new(uncompressed_body)
        #
        # @param uncompressed_body [HTTP::Request::Body]
        # @return [CompressedBody]
        # @api public
        def initialize(uncompressed_body)
          super(nil)
          @body       = uncompressed_body
          @compressed = nil
        end

        # Returns the size of the compressed body
        #
        # @example
        #   compressed_body.size
        #
        # @return [Integer]
        # @api public
        def size
          compress_all! unless @compressed
          @compressed.size
        end

        # Yields each chunk of compressed data
        #
        # @example
        #   compressed_body.each { |chunk| io.write(chunk) }
        #
        # @return [self, Enumerator]
        # @api public
        def each(&block)
          return to_enum(:each) unless block

          if @compressed
            compressed_each(&block)
          else
            compress(&block)
          end

          self
        end

        private

        # Yield each chunk from compressed data
        # @return [void]
        # @api private
        def compressed_each
          while (data = @compressed.read(Connection::BUFFER_SIZE))
            yield data
          end
        ensure
          @compressed.close!
        end

        # Compress all data to a tempfile
        # @return [void]
        # @api private
        def compress_all!
          @compressed = Tempfile.new("http-compressed_body", binmode: true)
          compress { |data| @compressed.write(data) }
          @compressed.rewind
        end
      end

      # Gzip-compressed request body wrapper
      class GzippedBody < CompressedBody
        # Compresses data using gzip
        #
        # @example
        #   gzipped_body.compress { |data| io.write(data) }
        #
        # @return [nil]
        # @api public
        def compress(&block)
          gzip = Zlib::GzipWriter.new(BlockIO.new(block))
          @body.each { |chunk| gzip.write(chunk) }
        ensure
          gzip.finish
        end

        # IO adapter that delegates writes to a block
        class BlockIO
          # Initializes a block-based IO adapter
          #
          # @example
          #   BlockIO.new(block)
          #
          # @param block [Proc]
          # @return [BlockIO]
          # @api public
          def initialize(block)
            @block = block
          end

          # Writes data by calling the block
          #
          # @example
          #   block_io.write("data")
          #
          # @param data [String]
          # @return [Object]
          # @api public
          def write(data)
            @block.call(data)
          end
        end
      end

      # Deflate-compressed request body wrapper
      class DeflatedBody < CompressedBody
        # Compresses data using deflate
        #
        # @example
        #   deflated_body.compress { |data| io.write(data) }
        #
        # @return [nil]
        # @api public
        def compress
          deflater = Zlib::Deflate.new

          @body.each { |chunk| yield deflater.deflate(chunk) }

          yield deflater.finish
        ensure
          deflater.close
        end
      end
    end
  end
end
