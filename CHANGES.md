0.6.4 (2015-03-25)
------------------

* SECURITY FIX: http.rb failed to call the `#post_connection_check` method on
  SSL connections. This method implements hostname verification, and without it
  `http.rb` was vulnerable to MitM attacks. The problem was corrected by calling
  `#post_connection_check` (CVE-2015-1828) (@zanker, backported by @nicoolas25)

0.6.3 (2014-11-14)
------------------

* Backported EOF fix from master branch. See #166. (@ixti)

0.6.2 (2014-08-06)
------------------

* Fix default Host header value. See #150. (@ixti)
* Deprecate BearerToken authorization header. (@ixti)
* Fix handling of chunked responses without Content-Length header. (@ixti)
* Rename `HTTP.with_follow` to `HTTP.follow` and mark former one as being
  deprecated (@ixti)

0.6.1 (2014-05-07)
------------------

* Fix request `Content-Length` calculation for Unicode (@challengeechallengee)
* Add `Response#flush` (@ixti)
* Fix `Response::Body#readpartial` default size (@hannesg, @ixti)
* Add missing `CRLF` for chunked bodies (@hannesg)
* Fix forgotten CGI require (@ixti)
* Improve README (@tarcieri)

0.6.0 (2014-04-04)
------------------

* Rename `HTTP::Request#method` to `HTTP::Request#verb` (@krainboltgreene)
* Add `HTTP::ResponseBody` class (@tarcieri)
* Change API of response on `HTTP::Client.request` and "friends" (`#get`, `#post`, etc) (@tarcieri)
* Add `HTTP::Response#readpartial` (@tarcieri)
* Add `HTTP::Headers` class (@ixti)
* Fix and improve following redirects (@ixti)
* Add `HTTP::Request#redirect` (@ixti)
* Add `HTTP::Response#content_type` (@ixti)
* Add `HTTP::Response#mime_type` (@ixti)
* Add `HTTP::Response#charset` (@ixti)
* Improve error message upon invalid URI scheme (@ixti)
* Consolidate errors under common `HTTP::Error` namespace (@ixti)
* Add easy way of adding Authorization header (@ixti)
* Fix proxy support (@hundredwatt)
* Fix and improve query params handing (@jwinter)
* Change API of custom MIME type parsers (@ixti)
* Remove `HTTP::Chainable#with_response` (@ixti)
* Remove `HTTP::Response::BodyDelegator` (@ixti)
* Remove `HTTP::Response#parsed_body` (@ixti)
* Bump up input buffer from 4K to 16K (@tarcieri)

``` ruby
# Main API change you will mention is that `request` method and it's
# syntax sugar helpers like `get`, `post`, etc. now returns Response
# object instead of BodyDelegator:

response = HTTP.get "http://example.com"
raw_body = HTTP.get("http://example.com").to_s
parsed_body = HTTP.get("http://example.com/users.json").parse

# Second major change in API is work with request/response headers
# It is now delegated to `HTTP::Headers` class, so you can check it's
# documentation for details, here we will only outline main difference.
# Duckface (`[]=`) does not appends headers anymore

request[:content_type] = "text/plain"
request[:content_type] = "text/html"
request[:content_type] # => "text/html"

# In order to add multiple header values, you should pass array:

request[:cookie] = ["foo=bar", "woo=hoo"]
request[:cookie] # => ["foo=bar", "woo=hoo"]

# or call `#add` on headers:

request.headers.add :accept, "text/plain"
request.headers.add :accept, "text/html"
request[:accept] # => ["text/plain", "text/html"]

# Also, you can now read body in chunks (stream):

res = HTTP.get "http://example.com"
File.open "/tmp/dummy.bin", "wb" do |io|
  while (chunk = res.readpartial)
    io << chunk
  end
end
```

[Changes discussion](https://github.com/tarcieri/http/issues/116)

0.5.1 (2014-05-27)
------------------

* Backports redirector fixes from 0.6.0 (@ixti)
* EOL of 0.5.X branch.

0.5.0
-----
* Add query string support
* New response delegator allows HTTP.get(uri).response
* HTTP::Chainable#stream provides a shorter alias for
  with_response(:object)
* Better string inspect for HTTP::Response
* Curb compatibility layer removed

0.4.0
-----
* Fix bug accessing https URLs
* Fix several instances of broken redirect handling
* Add default user agent
* Many additional minor bugfixes

0.3.0
-----
* New implementation based on tmm1's http_parser.rb instead of Net::HTTP
* Support for following redirects
* Support for request body through {:body => ...} option
* HTTP#with_response (through Chainable)

0.2.0
-----
* Request and response objects
* Callback system
* Internal refactoring ensuring true chainability
* Use the certified gem to ensure SSL certificate verification

0.1.0
-----
* Testing against WEBrick
* Curb compatibility (require 'http/compat/curb')

0.0.1
-----
* Initial half-baked release

0.0.0
-----
* Vapoware release to claim the "http" gem name >:D
