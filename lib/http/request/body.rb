# frozen_string_literal: true

module HTTP
  class Request
    class Body
      # Maximum chunk size used for reading content of an IO
      CHUNK_SIZE = Connection::BUFFER_SIZE

      def initialize(body)
        @body = body

        validate_body_type!
      end

      # Returns size which should be used for the "Content-Length" header.
      #
      # @return [Integer]
      def size
        if @body.is_a?(String)
          @body.bytesize
        elsif @body.respond_to?(:read)
          raise RequestError, "IO object must respond to #size" unless @body.respond_to?(:size)
          @body.size
        elsif @body.nil?
          0
        else
          raise RequestError, "cannot determine size of body: #{@body.inspect}"
        end
      end

      # Yields chunks of content to be streamed to the request body.
      #
      # @yieldparam [String]
      def each
        return enum_for(__method__) unless block_given?

        if @body.is_a?(String)
          yield @body
        elsif @body.respond_to?(:read)
          read_method = @body.respond_to?(:readpartial) ? :readpartial : :read

          begin
            while (data = @body.send(read_method, CHUNK_SIZE))
              yield data
            end
          rescue EOFError
            # done reading
          end
        elsif @body.is_a?(Enumerable)
          @body.each { |chunk| yield chunk }
        end
      end

      private

      def validate_body_type!
        return if @body.is_a?(String)
        return if @body.respond_to?(:read)
        return if @body.is_a?(Enumerable)
        return if @body.nil?

        raise RequestError, "body of wrong type: #{@body.class}"
      end
    end
  end
end
