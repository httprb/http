# frozen_string_literal: true

require "forwardable"

module HTTP
  # Thread-safe options builder for configuring HTTP requests.
  #
  # Session objects are returned by all chainable configuration methods
  # (e.g., {Chainable#headers}, {Chainable#timeout}, {Chainable#cookies}).
  # They hold an immutable {Options} object and create a new {Client}
  # for each request, making them safe to share across threads.
  #
  # @example Reuse a configured session across threads
  #   session = HTTP.headers("Accept" => "application/json").timeout(10)
  #   threads = 5.times.map do
  #     Thread.new { session.get("https://example.com") }
  #   end
  #   threads.each(&:join)
  #
  # @see Chainable
  # @see Client
  class Session
    extend Forwardable
    include Chainable

    # @!method persistent?
    #   Indicate whether the session has persistent connection options
    #
    #   @example
    #     session = HTTP::Session.new(persistent: "http://example.com")
    #     session.persistent?
    #
    #   @see Options#persistent?
    #   @return [Boolean]
    #   @api public
    def_delegator :default_options, :persistent?

    # Initialize a new Session
    #
    # @example
    #   session = HTTP::Session.new(headers: {"Accept" => "application/json"})
    #
    # @param default_options [Hash, Options] options for requests
    # @return [HTTP::Session] a new session instance
    # @api public
    def initialize(default_options = {})
      @default_options = HTTP::Options.new(default_options)
    end

    # Make an HTTP request by creating a new {Client}
    #
    # A fresh {Client} is created for each request, ensuring thread safety.
    #
    # @example
    #   session = HTTP::Session.new
    #   session.request(:get, "https://example.com")
    #
    # @param verb [Symbol] the HTTP method
    # @param uri [#to_s] the URI to request
    # @param opts [Hash] request options
    # @return [HTTP::Response] the response
    # @api public
    def request(verb, uri, opts = {})
      make_client(default_options).request(verb, uri, opts)
    end

    # Build an HTTP request without executing it
    #
    # @example
    #   session = HTTP::Session.new
    #   session.build_request(:get, "https://example.com")
    #
    # @param verb [Symbol] the HTTP method
    # @param uri [#to_s] the URI to request
    # @param opts [Hash] request options
    # @return [HTTP::Request] the built request object
    # @api public
    def build_request(verb, uri, opts = {})
      make_client(default_options).build_request(verb, uri, opts)
    end
  end
end
