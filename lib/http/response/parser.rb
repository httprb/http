# frozen_string_literal: true

require "http-parser"

module HTTP
  class Response
    # @api private
    #
    # NOTE(ixti): This class is a subject of future refactoring, thus don't
    #   expect this class API to be stable until this message disappears and
    #   class is not marked as private anymore.
    class Parser
      attr_reader :headers

      def initialize
        @state  = HttpParser::Parser.new_instance { |i| i.type = :response }
        @parser = HttpParser::Parser.new(self)

        reset
      end

      # @return [self]
      def add(data)
        # XXX(ixti): API doc of HttpParser::Parser is misleading, it says that
        #   it returns boolean true if data was parsed successfully, but instead
        #   it's response tells if there was an error; So when it's `true` that
        #   means parse failed, and `false` means parse was successful.
        #   case of success.
        return self unless @parser.parse(@state, data)

        raise IOError, "Could not parse data"
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
