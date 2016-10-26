# frozen_string_literal: true

require "zlib"

module HTTP
  module Features
    class AutoDeflate < Feature
      attr_reader :method

      def initialize(*)
        super

        @method = @opts.key?(:method) ? @opts[:method].to_s : "gzip"

        raise Error, "Only gzip and deflate methods are supported" unless %w(gzip deflate).include?(@method)
      end

      def deflate(headers, body)
        return body unless body
        return body unless body.is_a?(String)

        # We need to delete Content-Length header. It will be set automatically
        # by HTTP::Request::Writer
        headers.delete(Headers::CONTENT_LENGTH)

        headers[Headers::CONTENT_ENCODING] = method

        case method
        when "gzip" then
          StringIO.open do |out|
            Zlib::GzipWriter.wrap(out) do |gz|
              gz.write body
              gz.finish
              out.tap(&:rewind).read
            end
          end
        when "deflate" then
          Zlib::Deflate.deflate(body)
        else
          raise ArgumentError, "Unsupported deflate method: #{method}"
        end
      end
    end
  end
end
