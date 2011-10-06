module Http
  # We all know what HTTP clients are, right?
  class Client
    # I swear I'll document that nebulous options hash
    def initialize(uri, options = {})
      # Argument coersion is a bit gnarly, isn't it?
      case uri
      when String
        # Why the FUCK can't Net::HTTP do this?
        @uri = URI.parse(uri)
      when URI
        @uri = uri
      else
        if uri.respond_to :to_uri
          @uri = uri.to_uri
        else
          raise ArgumentError, "can't convert #{uri.class} to a URI"
        end
      end

      @options = options
    end

    def get(options = {})
      # Trolol these don't do anything yet
      options = @options.merge(options)

      # NO! Don't even thing about reusing the Net::HTTP options hash
      Net::HTTP.get(@uri)
    end
  end
end
