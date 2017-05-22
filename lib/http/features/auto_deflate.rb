# frozen_string_literal: true

require "zlib"
require "tempfile"

module HTTP
  module Features
    class AutoDeflate < Feature
      attr_reader :method

      def initialize(*)
        super

        @method = @opts.key?(:method) ? @opts[:method].to_s : "gzip"

        raise Error, "Only gzip and deflate methods are supported" unless %w(gzip deflate).include?(@method)
      end

      def deflated_body(body)
        case method
        when "gzip"
          GzippedBody.new(body)
        when "deflate"
          DeflatedBody.new(body)
        else
          raise ArgumentError, "Unsupported deflate method: #{method}"
        end
      end

      class CompressedBody
        def initialize(body)
          @body       = body
          @compressed = nil
        end

        def size
          compress_all! unless @compressed
          @compressed.size
        end

        def each(&block)
          return enum_for(__method__) unless block

          if @compressed
            begin
              while (data = @compressed.read(Connection::BUFFER_SIZE))
                block.call(data)
              end
            ensure
              @compressed.close!
            end
          else
            compress(&block)
          end
        end

        private

        def compress_all!
          @compressed = Tempfile.new("http-compressed_body", :binmode => true)
          compress { |data| @compressed.write(data) }
          @compressed.rewind
        end
      end

      class GzippedBody < CompressedBody
        def compress(&block)
          gzip = Zlib::GzipWriter.new(BlockIO.new(block))

          @body.each do |chunk|
            gzip.write(chunk)
          end
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
        def compress(&block)
          deflater = Zlib::Deflate.new

          @body.each do |chunk|
            deflater.deflate(chunk) { |data| block.call(data) }
          end

          deflater.finish { |data| block.call(data) }
        ensure
          deflater.close
        end
      end
    end
  end
end
