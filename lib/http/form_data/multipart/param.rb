# frozen_string_literal: true

require "http/form_data/readable"
require "http/form_data/composite_io"

module HTTP
  module FormData
    class Multipart
      # Utility class to represent multi-part chunks
      class Param
        include Readable

        # Initializes body part with headers and data
        #
        # @example With {FormData::File} value
        #
        #   Content-Disposition: form-data; name="avatar"; filename="avatar.png"
        #   Content-Type: application/octet-stream
        #
        #   ...data of avatar.png...
        #
        # @example With non-{FormData::File} value
        #
        #   Content-Disposition: form-data; name="username"
        #
        #   ixti
        #
        # @api public
        # @param [#to_s] name
        # @param [FormData::File, FormData::Part, #to_s] value
        # @return [Param]
        def initialize(name, value)
          @name = name.to_s
          @part = value.is_a?(Part) ? value : Part.new(value)
          @io   = CompositeIO.new [header, @part, CRLF]
        end

        private

        # Builds the MIME header for this part
        #
        # @api private
        # @return [String]
        def header
          header = "Content-Disposition: form-data; #{parameters}#{CRLF}"
          header << "Content-Type: #{@part.content_type}#{CRLF}" if @part.content_type
          header << CRLF
        end

        # Builds Content-Disposition parameters string
        #
        # @api private
        # @return [String]
        def parameters
          params = "name=#{@name.inspect}"
          params << "; filename=#{@part.filename.inspect}" if @part.filename
          params
        end
      end
    end
  end
end
