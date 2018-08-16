# frozen_string_literal: true

module HTTP
  module Features
    class AutoInflate < Feature
      def wrap_response(response)
        return response unless %w[deflate gzip x-gzip].include?(response.headers[:content_encoding])
        Response.new(
          :status => response.status,
          :version => response.version,
          :headers => response.headers,
          :proxy_headers => response.proxy_headers,
          :connection => response.connection,
          :body => stream_for(response.connection)
        )
      end

      def stream_for(connection)
        Response::Body.new(Response::Inflater.new(connection))
      end

      HTTP::Options.register_feature(:auto_inflate, self)
    end
  end
end
