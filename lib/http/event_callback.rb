module Http
  class EventCallback
    include Chainable

    def initialize(event, callbacks, &block)
      self.event_callbacks = callbacks
      @block = block
      callbacks[event] ||= []
      callbacks[event] << self
    end

    def invoke(request_or_response)
      @block.call(request_or_response)
    end
  end
end
