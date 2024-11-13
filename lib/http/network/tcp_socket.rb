# frozen_string_literal: true

require "socket"

module HTTP
  module Network
    class TCPSocket
      class << self
        def new(...)
          ::Socket.tcp(...)
        end

        def open(...)
          new(...)
        end
      end
    end
  end
end
