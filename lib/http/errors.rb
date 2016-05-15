# frozen_string_literal: true
module HTTP
  # Generic error
  class Error < StandardError; end

  # Generic Connection error
  class ConnectionError < Error; end

  # Generic Request error
  class RequestError < Error; end

  # Generic Response error
  class ResponseError < Error; end

  # Requested to do something when we're in the wrong state
  class StateError < ResponseError; end

  # Generic Timeout error
  class TimeoutError < Error; end

  # Header name is invalid
  class InvalidHeaderNameError < Error; end
end
