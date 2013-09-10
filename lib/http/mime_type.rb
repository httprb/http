module HTTP
  # Yes, HTTP bundles its own MIME type library. Maybe it should be spun off
  # as a separate gem or something.
  class MimeType
    @mime_types, @shortcuts = {}, {}

    class << self
      def register(obj)
        @mime_types[obj.type] = obj
        @shortcuts[obj.shortcut] = obj if obj.shortcut
      end

      def [](type)
        if type.is_a? Symbol
          @shortcuts[type]
        else
          @mime_types[type]
        end
      end
    end

    attr_reader :type, :shortcut

    def initialize(type, shortcut = nil)
      @type, @shortcut = type, shortcut
      @parse_with = @emit_with = nil

      self.class.register self
    end

    # Define
    def parse_with(&block)
      @parse_with = block
    end

    def emit_with(&block)
      @emit_with = block
    end

    def parse(obj)
      @parse_with ? @parse_with[obj] : obj
    end

    def emit(obj)
      @emit_with  ? @emit_with[obj]  : obj
    end
  end
end

# MIME type registry
require 'http/mime_types/json'
