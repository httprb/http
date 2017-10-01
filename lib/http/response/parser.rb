# frozen_string_literal: true

require "http-parser"

module HTTP
  class Response
    class Parser
      attr_reader :headers

      def initialize
        @state  = HttpParser::Parser.new_instance { |i| i.type = :response }
        @parser = HttpParser::Parser.new(self)

        reset
      end

      def add(data)
        @parser.parse(@state, data)
      end
      alias << add

      def headers?
        @finished[:headers]
      end

      def http_version
        @state.http_version
      end

      def status_code
        @state.http_status
      end

      #
      # HTTP::Parser callbacks
      #

      def on_header_field(_response, field)
        @field = field
      end

      def on_header_value(_response, value)
        @headers.add(@field, value) if @field
      end

      def on_headers_complete(_reposse)
        @finished[:headers] = true
      end

      def on_body(_response, chunk)
        if @chunk
          @chunk << chunk
        else
          @chunk = chunk
        end
      end

      def chunk
        chunk  = @chunk
        @chunk = nil
        chunk
      end

      def on_message_complete(_response)
        @finished[:message] = true
      end

      def reset
        @state.reset!

        @finished = Hash.new(false)
        @headers  = HTTP::Headers.new
        @field    = nil
        @chunk    = nil
      end

      def finished?
        @finished[:message]
      end
    end
  end
end
