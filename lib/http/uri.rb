require "addressable/uri"

module HTTP
  class URI < Addressable::URI
    # @private
    HTTP_SCHEME = "http".freeze

    # @private
    HTTPS_SCHEME = "https".freeze

    # @return [True] if URI is HTTP
    # @return [False] otherwise
    def http?
      HTTP_SCHEME == scheme
    end

    # @return [True] if URI is HTTPS
    # @return [False] otherwise
    def https?
      HTTPS_SCHEME == scheme
    end

    # @return [String] human-readable representation of URI
    def inspect
      format("#<%s:%#0x URI:%s>", self.class, object_id, to_s)
    end
  end
end
