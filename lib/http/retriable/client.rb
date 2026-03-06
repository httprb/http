# frozen_string_literal: true

require "http/retriable/performer"

module HTTP
  module Retriable
    # Retriable version of HTTP::Client.
    #
    # @see http://www.rubydoc.info/gems/http/HTTP/Client
    class Client < HTTP::Client
      # Initializes a retriable client
      #
      # @example
      #   HTTP::Retriable::Client.new(performer, options)
      #
      # @param [Performer] performer
      # @param [HTTP::Options, Hash] options
      # @api public
      # @return [HTTP::Retriable::Client]
      def initialize(performer, options)
        @performer = performer
        super(options)
      end

      # Performs request with retry logic
      #
      # @example
      #   client.perform(request, options)
      #
      # @param [HTTP::Request] req
      # @param [HTTP::Options] options
      # @see http://www.rubydoc.info/gems/http/HTTP/Client:perform
      # @api public
      # @return [HTTP::Response]
      def perform(req, options)
        @performer.perform(self, req) { super(req, options) }
      end

      private

      # Creates a new branch of the retriable client
      #
      # @param [HTTP::Options] options
      # @api private
      # @return [HTTP::Retriable::Client]
      def branch(options)
        Retriable::Client.new(@performer, options)
      end
    end
  end
end
