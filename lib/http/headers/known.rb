module HTTP
  class Headers
    # Content-Types that are acceptable for the response.
    ACCEPT = "Accept".freeze

    # The age the object has been in a proxy cache in seconds.
    AGE = "Age".freeze

    # Authentication credentials for HTTP authentication.
    AUTHORIZATION = "Authorization".freeze

    # Used to specify directives that must be obeyed by all caching mechanisms
    # along the request-response chain.
    CACHE_CONTROL = "Cache-Control".freeze

    # An HTTP cookie previously sent by the server with Set-Cookie.
    COOKIE = "Cookie".freeze

    # Control options for the current connection and list
    # of hop-by-hop request fields.
    CONNECTION = "Connection".freeze

    # The length of the request body in octets (8-bit bytes).
    CONTENT_LENGTH = "Content-Length".freeze

    # The MIME type of the body of the request
    # (used with POST and PUT requests).
    CONTENT_TYPE = "Content-Type".freeze

    # The date and time that the message was sent (in "HTTP-date" format as
    # defined by RFC 7231 Date/Time Formats).
    DATE = "Date".freeze

    # An identifier for a specific version of a resource,
    # often a message digest.
    ETAG = "ETag".freeze

    # Gives the date/time after which the response is considered stale (in
    # "HTTP-date" format as defined by RFC 7231).
    EXPIRES = "Expires".freeze

    # The domain name of the server (for virtual hosting), and the TCP port
    # number on which the server is listening. The port number may be omitted
    # if the port is the standard port for the service requested.
    HOST = "Host".freeze

    # Allows a 304 Not Modified to be returned if content is unchanged.
    IF_MODIFIED_SINCE = "If-Modified-Since".freeze

    # Allows a 304 Not Modified to be returned if content is unchanged.
    IF_NONE_MATCH = "If-None-Match".freeze

    # The last modified date for the requested object (in "HTTP-date" format as
    # defined by RFC 7231).
    LAST_MODIFIED = "Last-Modified".freeze

    # Used in redirection, or when a new resource has been created.
    LOCATION = "Location".freeze

    # Authorization credentials for connecting to a proxy.
    PROXY_AUTHORIZATION = "Proxy-Authorization".freeze

    # An HTTP cookie.
    SET_COOKIE = "Set-Cookie".freeze

    # The form of encoding used to safely transfer the entity to the user.
    # Currently defined methods are: chunked, compress, deflate, gzip, identity.
    TRANSFER_ENCODING = "Transfer-Encoding".freeze

    # The user agent string of the user agent.
    USER_AGENT = "User-Agent".freeze

    # Tells downstream proxies how to match future request headers to decide
    # whether the cached response can be used rather than requesting a fresh
    # one from the origin server.
    VARY = "Vary".freeze
  end
end
