# frozen_string_literal: true

module HTTP
  class Request
    class Body
      # The source data for this body
      #
      # @example
      #   body.source # => "hello world"
      #
      # @return [String, Enumerable, IO, nil]
      # @api public
      attr_reader :source

      # Initialize a new request body
      #
      # @example
      #   Body.new("hello world")
      #
      # @return [HTTP::Request::Body]
      # @api public
      def initialize(source)
        @source = source

        validate_source_type!
      end

      # Returns size for the "Content-Length" header
      #
      # @example
      #   body.size
      #
      # @return [Integer]
      # @api public
      def size
        if @source.is_a?(String)
          @source.bytesize
        elsif @source.respond_to?(:read)
          raise RequestError, "IO object must respond to #size" unless @source.respond_to?(:size)

          @source.size
        elsif @source.nil?
          0
        else
          raise RequestError, "cannot determine size of body: #{@source}"
        end
      end

      # Yields chunks of content to be streamed
      #
      # @example
      #   body.each { |chunk| socket.write(chunk) }
      #
      # @yieldparam [String]
      # @return [self]
      # @api public
      def each(&block)
        if @source.is_a?(String)
          yield @source
        elsif @source.respond_to?(:read)
          IO.copy_stream(@source, ProcIO.new(block))
          rewind(@source)
        elsif @source
          @source.each(&block)
        end

        self
      end

      # Check equality based on source
      #
      # @example
      #   body == other_body
      #
      # @return [Boolean]
      # @api public
      def ==(other)
        other.is_a?(self.class) && source == other.source
      end

      private

      # Rewind an IO source if possible
      # @return [void]
      # @api private
      def rewind(io)
        io.rewind if io.respond_to? :rewind
      rescue Errno::ESPIPE, Errno::EPIPE
        # Pipe IOs respond to `:rewind` but fail when you call it.
        #
        # Calling `IO#rewind` on a pipe, fails with *ESPIPE* on MRI,
        # but *EPIPE* on jRuby.
        #
        # - **ESPIPE** -- "Illegal seek."
        #   Invalid seek operation (such as on a pipe).
        #
        # - **EPIPE** -- "Broken pipe."
        #   There is no process reading from the other end of a pipe. Every
        #   library function that returns this error code also generates
        #   a SIGPIPE signal; this signal terminates the program if not handled
        #   or blocked. Thus, your program will never actually see EPIPE unless
        #   it has handled or blocked SIGPIPE.
        #
        # See: https://www.gnu.org/software/libc/manual/html_node/Error-Codes.html
        nil
      end

      # Validate that source is a supported type
      # @return [void]
      # @api private
      def validate_source_type!
        return if @source.is_a?(String)
        return if @source.respond_to?(:read)
        return if @source.is_a?(Enumerable)
        return if @source.nil?

        raise RequestError, "body of wrong type: #{@source.class}"
      end

      # This class provides a "writable IO" wrapper around a proc object, with
      # #write simply calling the proc, which we can pass in as the
      # "destination IO" in IO.copy_stream.
      class ProcIO
        # Initialize a new ProcIO wrapper
        #
        # @example
        #   ProcIO.new(block)
        #
        # @return [ProcIO]
        # @api public
        def initialize(block)
          @block = block
        end

        # Write data by calling the wrapped proc
        #
        # @example
        #   proc_io.write("hello")
        #
        # @return [Integer]
        # @api public
        def write(data)
          @block.call(data)
          data.bytesize
        end
      end
    end
  end
end
