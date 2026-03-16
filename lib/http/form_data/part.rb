# frozen_string_literal: true

require "stringio"

require "http/form_data/readable"

module HTTP
  module FormData
    # Represents a body part of multipart/form-data request.
    #
    # @example Usage with String
    #
    #  body = "Message"
    #  FormData::Part.new body, content_type: 'foobar.txt; charset="UTF-8"'
    class Part
      include Readable

      # Returns the content type of this part
      #
      # @example
      #   part.content_type # => "application/json"
      #
      # @api public
      # @return [String, nil]
      attr_reader :content_type

      # Returns the filename of this part
      #
      # @example
      #   part.filename # => "avatar.png"
      #
      # @api public
      # @return [String, nil]
      attr_reader :filename

      # Creates a new Part with the given body and options
      #
      # @example
      #   Part.new("hello", content_type: "text/plain")
      #
      # @api public
      # @param [#to_s] body
      # @param [String] content_type Value of Content-Type header
      # @param [String] filename     Value of filename parameter
      def initialize(body, content_type: nil, filename: nil)
        @io = StringIO.new(body.to_s)
        @content_type = content_type
        @filename = filename
      end
    end
  end
end
