# frozen_string_literal: true

require "llhttp"

module HTTP
  class Response
    # @api private

    class LLParsingHandler < ::LLHttp::Delegate
      def initialize(target)
        @target = target
        super()
        reset
      end

      def reset
        @header_field = nil
      end

      def on_header_field(field)
        @header_field = field
      end

      def on_header_value(value)
        return unless @header_field
        @target.add_header(@header_field, value)
        @header_field = nil
      end

      def on_headers_complete
        @target.status_code = @target.parser.status_code
        @target.http_version = "#{@target.parser.http_major}.#{@target.parser.http_minor}"
        @target.mark_header_finished
      end

      def on_body(body)
        @target.add_body(body)
      end

      def on_message_complete
        @target.mark_message_finished
      end
    end

    class LLParser
      attr_reader \
        :parser,
        :headers
      attr_accessor \
        :status_code,
        :http_version

      def initialize
        @parsing_handler = LLParsingHandler.new(self)
        @parser = ::LLHttp::Parser.new(
          @parsing_handler,
          type: :response
        )
        reset
      end

      def reset
        @parsing_handler.reset
        @header_finished = false
        @message_finished = false
        @headers = Headers.new
        @body_buffer&.close
        @body_buffer&.clear
        @body_buffer = ::Queue.new
        @read_buffer = ""
      end

      # @return [self]
      def add(data)
        (parser << data).tap do |success|
          raise IOError, "Could not parse data" unless success
          break self
        end
      end

      alias << add

      def mark_header_finished
        @header_finished = true
      end

      def headers?
        @header_finished
      end

      def add_header(name, value)
        @headers.add(name, value)
      end

      def mark_message_finished
        @message_finished = true
        @body_buffer.close if @body_buffer.respond_to?(:close)
      end

      def finished?
        @message_finished
      end

      def add_body(chunk)
        @body_buffer.enq(chunk)
      end

      def read(size)
        loop do
          @read_buffer = "#{@read_buffer}#{@body_buffer.deq(true)}"
          break if size <= @read_buffer.bytesize
        rescue ::StopIteration, ::ThreadError
          break
        end
        @read_buffer.byteslice(0, size).tap do |chunk|
          @read_buffer = @read_buffer.byteslice(
            (size)...(@read_buffer.bytesize)
          ) || ""
          break nil if chunk.empty?
        end
      end
    end
  end
end
