module HTTP
  # Generic error
  class Error < StandardError; end

  # Generic Request error
  class RequestError < Error; end

  # Generic Response error
  class ResponseError < Error; end

  # Request to do something when we're in the wrong state
  class StateError < ResponseError; end
end
