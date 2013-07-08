module HTTP
  # RFC 2616: Hypertext Transfer Protocol -- HTTP/1.1
  METHODS = [:options, :get, :head, :post, :put, :delete, :trace, :connect]

  # RFC 2518: HTTP Extensions for Distributed Authoring -- WEBDAV
  METHODS.concat [:propfind, :proppatch, :mkcol, :copy, :move, :lock, :unlock]

  # RFC 3648: WebDAV Ordered Collections Protocol
  METHODS.concat [:orderpatch]

  # RFC 3744: WebDAV Access Control Protocol
  METHODS.concat [:acl]

  # draft-dusseault-http-patch: PATCH Method for HTTP
  METHODS.concat [:patch]

  # draft-reschke-webdav-search: WebDAV Search
  METHODS.concat [:search]
end
