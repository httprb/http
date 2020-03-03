# frozen_string_literal: true

require "http/retriable/performer"

module HTTP
  module Retriable
    # Retriable version of HTTP::Client.
    #
    # @see http://www.rubydoc.info/gems/http/HTTP/Client
    class Client < HTTP::Client
      # @param [Performer] performer
      # @param [HTTP::Options, Hash] options
      def initialize(performer, options)
        @performer = performer
        super(options)
      end

      # Overriden version of `HTTP::Client#make_request`.
      #
      # Monitors request/response phase with performer.
      #
      # @see http://www.rubydoc.info/gems/http/HTTP/Client:perform
      def perform(req, options)
        @performer.perform(self, req) { super(req, options) }
      end

      private

      # Overriden version of `HTTP::Chainable#branch`.
      #
      # @return [HTTP::Retriable::Client]
      def branch(options)
        Retriable::Client.new(@performer, options)
      end
    end
  end
end
