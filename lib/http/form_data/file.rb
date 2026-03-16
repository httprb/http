# frozen_string_literal: true

module HTTP
  module FormData
    # Represents file form param.
    #
    # @example Usage with StringIO
    #
    #  io = StringIO.new "foo bar baz"
    #  FormData::File.new io, filename: "foobar.txt"
    #
    # @example Usage with IO
    #
    #  File.open "/home/ixti/avatar.png" do |io|
    #    FormData::File.new io
    #  end
    #
    # @example Usage with pathname
    #
    #  FormData::File.new "/home/ixti/avatar.png"
    class File < Part
      # Default MIME type
      DEFAULT_MIME = "application/octet-stream"

      # Creates a new File from a path or IO object
      #
      # @example
      #   File.new("/path/to/file.txt")
      #
      # @api public
      # @see DEFAULT_MIME
      # @param [String, Pathname, IO] path_or_io Filename or IO instance
      # @param [#to_h] opts
      # @option opts [#to_s] :content_type (DEFAULT_MIME)
      #   Value of Content-Type header
      # @option opts [#to_s] :filename
      #   When `path_or_io` is a String, Pathname or File, defaults to basename.
      #   When `path_or_io` is a IO, defaults to `"stream-{object_id}"`
      def initialize(path_or_io, opts = nil) # rubocop:disable Lint/MissingSuper
        opts = FormData.ensure_hash(opts)

        @io           = make_io(path_or_io)
        @autoclose    = path_or_io.is_a?(String) || path_or_io.is_a?(Pathname)
        @content_type = opts.fetch(:content_type, DEFAULT_MIME).to_s
        @filename     = opts.fetch(:filename, filename_for(@io))
      end

      # Closes the underlying IO if it was opened by this instance
      #
      # When the File was created from a String path or Pathname, the
      # underlying file handle is closed. When created from an existing
      # IO object, this is a no-op (the caller is responsible for
      # closing it).
      #
      # @example
      #   file = FormData::File.new("/path/to/file.txt")
      #   file.to_s
      #   file.close
      #
      # @api public
      # @return [void]
      def close
        @io.close if @autoclose
      end

      private

      # Wraps path_or_io into an IO object
      #
      # @api private
      # @param [String, Pathname, IO] path_or_io
      # @return [IO]
      def make_io(path_or_io)
        case path_or_io
        when String   then ::File.new(path_or_io, binmode: true)
        when Pathname then path_or_io.open(binmode: true)
        else path_or_io
        end
      end

      # Determines filename for the given IO
      #
      # @api private
      # @param [IO] io
      # @return [String]
      def filename_for(io)
        if io.respond_to?(:path)
          ::File.basename(io.path)
        else
          "stream-#{io.object_id}"
        end
      end
    end
  end
end
