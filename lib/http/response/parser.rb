# frozen_string_literal: true

require "llhttp"

module HTTP
  class Response
    # HTTP response parser backed by LLHttp
    # @api private
    class Parser
      # The underlying LLHttp parser
      # @return [LLHttp::Parser] the underlying parser
      # @api private
      attr_reader :parser

      # The parsed response headers
      # @return [HTTP::Headers] the parsed headers
      # @api private
      attr_reader :headers

      # The parsed HTTP status code
      # @return [Integer, nil] the parsed status code
      # @api private
      attr_reader :status_code

      # The parsed HTTP version string
      # @return [String, nil] the parsed HTTP version
      # @api private
      attr_reader :http_version

      # Create a new response parser
      # @return [Parser]
      # @api private
      def initialize
        @handler = Handler.new(self)
        @parser = LLHttp::Parser.new(@handler, type: :response)
        reset
      end

      # Reset parser to initial state
      # @return [void]
      # @api private
      def reset
        @parser.reset
        @handler.reset
        @header_finished = false
        @message_finished = false
        @headers = Headers.new
        @chunk = nil
        @status_code = nil
        @http_version = nil
      end

      # Feed data into the parser
      # @return [Parser]
      # @api private
      def add(data)
        parser << data

        self
      rescue LLHttp::Error => e
        raise IOError, e.message
      end

      # @see #add
      # @api private
      alias << add

      # Mark headers as finished
      # @return [void]
      # @api private
      def mark_header_finished
        @header_finished = true
        @status_code = @parser.status_code
        @http_version = "#{@parser.http_major}.#{@parser.http_minor}"
      end

      # Check if headers have been parsed
      # @return [Boolean]
      # @api private
      def headers?
        @header_finished
      end

      # Add a parsed header field and value
      # @return [void]
      # @api private
      def add_header(name, value)
        @headers.add(name, value)
      end

      # Mark the message as fully parsed
      # @return [void]
      # @api private
      def mark_message_finished
        @message_finished = true
      end

      # Check if the full message has been parsed
      # @return [Boolean]
      # @api private
      def finished?
        @message_finished
      end

      # Append a body chunk to the buffer
      # @return [void]
      # @api private
      def add_body(chunk)
        if @chunk
          @chunk << chunk
        else
          @chunk = chunk
        end
      end

      # Read up to size bytes from the body buffer
      # @return [String, nil]
      # @api private
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

      # Delegate handler for LLHttp parser callbacks
      # @api private
      class Handler < LLHttp::Delegate
        # Create a new parser handler
        # @return [Handler]
        # @api private
        def initialize(target)
          @target = target
          super()
          reset
        end

        # Reset handler state
        # @return [void]
        # @api private
        def reset
          @reading_header_value = false
          @field_value = +""
          @field = +""
        end

        # Handle a header field token
        # @return [void]
        # @api private
        def on_header_field(field)
          append_header if @reading_header_value
          @field << field
        end

        # Handle a header value token
        # @return [void]
        # @api private
        def on_header_value(value)
          @reading_header_value = true
          @field_value << value
        end

        # Handle headers complete callback
        # @return [void]
        # @api private
        def on_headers_complete
          append_header if @reading_header_value
          @target.mark_header_finished
        end

        # Handle body data callback
        # @return [void]
        # @api private
        def on_body(body)
          @target.add_body(body)
        end

        # Handle message complete callback
        # @return [void]
        # @api private
        def on_message_complete
          @target.mark_message_finished
        end

        private

        # Flush the current header to the parser
        # @return [void]
        # @api private
        def append_header
          @target.add_header(@field, @field_value)
          @reading_header_value = false
          @field_value = +""
          @field = +""
        end
      end
    end
  end
end
