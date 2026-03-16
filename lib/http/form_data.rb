# frozen_string_literal: true

require "http/form_data/part"
require "http/form_data/file"
require "http/form_data/multipart"
require "http/form_data/urlencoded"
require "http/form_data/version"

# http gem namespace.
# @see https://github.com/httprb/http
module HTTP
  # Utility-belt to build form data request bodies.
  # Provides support for `application/x-www-form-urlencoded` and
  # `multipart/form-data` types.
  #
  # @example Usage
  #
  #   form = FormData.create({
  #     username:    "ixti",
  #     avatar_file: FormData::File.new("/home/ixti/avatar.png")
  #   })
  #
  #   # Assuming socket is an open socket to some HTTP server
  #   socket << "POST /some-url HTTP/1.1\r\n"
  #   socket << "Host: example.com\r\n"
  #   socket << "Content-Type: #{form.content_type}\r\n"
  #   socket << "Content-Length: #{form.content_length}\r\n"
  #   socket << "\r\n"
  #   socket << form.to_s
  module FormData
    # CRLF
    CRLF = "\r\n"

    # Generic FormData error.
    class Error < StandardError; end

    class << self
      # Selects encoder type based on given data
      #
      # @example
      #   FormData.create({ username: "ixti" })
      #
      # @api public
      # @param [Enumerable, Hash, #to_h] data
      # @return [Multipart] if any of values is a {FormData::File}
      # @return [Urlencoded] otherwise
      def create(data, encoder: nil)
        data = ensure_data data

        if multipart?(data)
          Multipart.new(data)
        else
          Urlencoded.new(data, encoder: encoder)
        end
      end

      # Coerces obj to Hash
      #
      # @example
      #   FormData.ensure_hash({ foo: :bar }) # => { foo: :bar }
      #
      # @api public
      # @raise [Error] `obj` can't be coerced
      # @return [Hash]
      def ensure_hash(obj)
        if    obj.is_a?(Hash)        then obj
        elsif obj.respond_to?(:to_h) then obj.to_h
        else raise Error, "#{obj.inspect} is neither Hash nor responds to :to_h"
        end
      end

      # Coerces obj to an Enumerable of key-value pairs
      #
      # @example
      #   FormData.ensure_data([[:foo, :bar]]) # => [[:foo, :bar]]
      #
      # @api public
      # @raise [Error] `obj` can't be coerced
      # @return [Enumerable]
      def ensure_data(obj)
        if    obj.nil?                  then []
        elsif obj.is_a?(Enumerable)     then obj
        elsif obj.respond_to?(:to_h)    then obj.to_h
        else raise Error, "#{obj.inspect} is neither Enumerable nor responds to :to_h"
        end
      end

      private

      # Checks if data contains multipart data
      #
      # @api private
      # @param [Enumerable] data
      # @return [Boolean]
      def multipart?(data)
        data.any? do |_, v|
          v.is_a?(Part) || (v.respond_to?(:to_ary) && v.to_ary.any?(Part))
        end
      end
    end
  end
end
