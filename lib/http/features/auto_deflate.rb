# frozen_string_literal: true

require "zlib"
require "tempfile"

require "http/request/body"

module HTTP
  module Features
    class AutoDeflate < Feature
      attr_reader :method

      def initialize(*)
        super

        @method = @opts.key?(:method) ? @opts[:method].to_s : "gzip"

        raise Error, "Only gzip and deflate methods are supported" unless %w[gzip deflate].include?(@method)
      end

      def wrap_request(request)
        return request unless method
        return request if request.body.size.zero?

        # We need to delete Content-Length header. It will be set automatically by HTTP::Request::Writer
        request.headers.delete(Headers::CONTENT_LENGTH)
        request.headers[Headers::CONTENT_ENCODING] = method

        Request.new(
          :version => request.version,
          :verb => request.verb,
          :uri => request.uri,
          :headers => request.headers,
          :proxy => request.proxy,
          :body => deflated_body(request.body),
          :uri_normalizer => request.uri_normalizer
        )
      end

      def deflated_body(body)
        case method
        when "gzip"
          GzippedBody.new(body)
        when "deflate"
          DeflatedBody.new(body)
        end
      end

      HTTP::Options.register_feature(:auto_deflate, self)

      class CompressedBody < HTTP::Request::Body
        def initialize(uncompressed_body)
          @body       = uncompressed_body
          @compressed = nil
        end

        def size
          compress_all! unless @compressed
          @compressed.size
        end

        def each(&block)
          return to_enum __method__ unless block

          if @compressed
            compressed_each(&block)
          else
            compress(&block)
          end

          self
        end

        private

        def compressed_each
          while (data = @compressed.read(Connection::BUFFER_SIZE))
            yield data
          end
        ensure
          @compressed.close!
        end

        def compress_all!
          @compressed = Tempfile.new("http-compressed_body", :binmode => true)
          compress { |data| @compressed.write(data) }
          @compressed.rewind
        end
      end

      class GzippedBody < CompressedBody
        def compress(&block)
          gzip = Zlib::GzipWriter.new(BlockIO.new(block))
          @body.each { |chunk| gzip.write(chunk) }
        ensure
          gzip.finish
        end

        class BlockIO
          def initialize(block)
            @block = block
          end

          def write(data)
            @block.call(data)
          end
        end
      end

      class DeflatedBody < CompressedBody
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
