# frozen_string_literal: true

require "http/retriable/performer"

module HTTP
  module Retriable
    # Thread-safe options builder with retry support.
    #
    # Returned by {Chainable#retriable}, this session creates a new
    # {Retriable::Client} for each request, preserving retry behavior
    # while remaining thread-safe.
    #
    # @see HTTP::Session
    # @see Retriable::Client
    class Session < HTTP::Session
      # Initializes a retriable session
      #
      # @example
      #   HTTP::Retriable::Session.new(performer, options)
      #
      # @param [Performer] performer
      # @param [HTTP::Options, Hash] options
      # @api public
      # @return [HTTP::Retriable::Session]
      def initialize(performer, options)
        @performer = performer
        super(options)
      end

      private

      # Creates a new branch of the retriable session
      #
      # @param [HTTP::Options] options
      # @api private
      # @return [HTTP::Retriable::Session]
      def branch(options)
        Retriable::Session.new(@performer, options)
      end

      # Creates a Retriable::Client for executing a single request
      #
      # @param [HTTP::Options] options
      # @api private
      # @return [HTTP::Retriable::Client]
      def make_client(options)
        Retriable::Client.new(@performer, options)
      end
    end
  end
end
