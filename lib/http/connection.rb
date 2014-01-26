require 'http/response/parser'

module HTTP
  # A connection to the HTTP server
  class Connection
    CONNECTION         = 'Connection'.freeze
    TRANSFER_ENCODING  = 'Transfer-Encoding'.freeze
    KEEP_ALIVE         = 'Keep-Alive'.freeze
    CLOSE              = 'close'.freeze

    attr_reader   :socket, :parser, :current_response
    attr_accessor :request_state, :response_state

    # Attempt to read this much data
    BUFFER_SIZE = 16384
    attr_reader :buffer_size

    def initialize(socket, buffer_size = nil)
      @socket      = socket
      @keepalive   = true
      @buffer_size = buffer_size || BUFFER_SIZE
      @parser      = Response::Parser.new(self)

      @request_state  = :headers
      @response_state = :headers
      reset_response
    end

    # Is the connection still active?
    def alive?; @keepalive; end

    # Send a request to the server
    # Response can be a symbol indicating the status code or a HTTP::Response
    def respond(response, headers_or_body = {}, body = nil)
      raise StateError, "not in header state" if @response_state != :headers

      if headers_or_body.is_a? Hash
        headers = headers_or_body
      else
        headers = {}
        body = headers_or_body
      end

      if @keepalive
        headers[CONNECTION] = KEEP_ALIVE
      else
        headers[CONNECTION] = CLOSE
      end

      case response
      when Symbol
        response = Response.new(response, headers, body)
      when Response
      else raise TypeError, "invalid response: #{response.inspect}"
      end

      if current_request
        current_request.handle_response(response)
      else
        raise RequestError
      end

      # Enable streaming mode
      if response.chunked? and response.body.nil?
        @response_state = :chunked_body
      elsif @keepalive
        reset_request
      else
        @current_request = nil
        @parser.reset
        @request_state = :closed
      end
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE, RequestError
      # The client disconnected early, or there is no request
      @keepalive = false
      @request_state = :closed
    end

    def readpartial(size = @buffer_size)
      unless @request_state == :headers || @request_state == :body
        raise StateError, "can't read in the '#{@request_fsm.state}' request state"
      end

      @parser.readpartial(size)
    end

    # Close the connection
    def close
      @keepalive = false
      @socket.close unless @socket.closed?
    end

    # Reset the current response state
    def reset_response
      @response_state  = :headers
      @current_request = nil
      @parser.reset
    end
    private :reset_response

    # Set response state for the connection.
    def response_state=(state)
      reset_response if state == :headers
      @response_state = state
    end
  end
end
