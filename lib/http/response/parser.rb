# frozen_string_literal: true

require "http-parser"

module HTTP
  class Response
    class Parser
      attr_reader :headers

      def initialize
        @instance = HttpParser::Parser.new_instance { |i| i.type = :response }
        @parser   = HttpParser::Parser.new(self)

        reset!
      end

      def add(data)
        @parser.parse(@instance, data)
      end
      alias << add

      def headers?
        @headers_complete
      end

      def finished?
        @message_complete
      end

      def http_version
        @instance.http_version
      end

      def status_code
        @instance.http_status
      end

      #
      # HTTP::Parser callbacks
      #

      def on_headers_complete(_)
        @headers_complete = true
      end

      def on_message_complete(_)
        @message_complete = true
      end

      def on_header_field(_, field)
        @header_field = field
        @header_value = nil
      end

      def on_header_value(_, value)
        return @header_value << value if @header_value

        @header_value = value
        @headers.add(@header_field, @header_value)
      end

      def on_body(_, chunk)
        if @chunk
          @chunk << chunk
        else
          @chunk = chunk
        end
      end

      def read(size)
        return if @chunk.nil?

        if @chunk.bytesize <= size
          chunk  = @chunk
          @chunk = nil
        else
          chunk = @chunk.byteslice(0, size)
          @chunk[0, size] = ""
        end

        chunk
      end

      def reset!
        @instance.reset!

        @headers_complete = false
        @message_complete = false
        @header_field     = nil
        @header_value     = nil
        @headers          = HTTP::Headers.new
        @chunk            = nil
      end
      alias reset reset!
    end
  end
end
