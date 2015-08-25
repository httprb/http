## 0.9.4 (2015-08-26)

* Fixes regression when body streaming was failing on some URIs.
  See #246. (@zanker)
* Fixes require timeout statements. See #243. (@ixti)


## 0.9.3 (2015-08-19)

* Fixed request URI normalization. See #246. (@ixti)
  - Avoids query component normalization
  - Omits fragment component in headline


## 0.9.2 (2015-08-18)

* Fixed exceptionless NIO EOF handling. (@zanker)


## 0.9.1 (2015-08-14)

* Fix params special-chars escaping. See #246. (@ixti)


## 0.9.0 (2015-07-23)

* Support for caching removed. See #240. (@tarcieri)
* JRuby 9000 compatibility


## 0.8.14 (2015-08-19)

* Backport request URI normalization fixes from master. (@ixti)


## 0.8.13 (2015-08-14)

* Backport params special-chars escaping fix from `v0.9.1`. (@ixti)


## 0.8.12 (2015-05-26)

* Fix `HTTP.timeout` API (was loosing previously defined options). (@ixti)


## 0.8.11 (2015-05-22)

* SNI support for HTTPS connections. See #229. (@tarcieri)
* Use "http.rb" in the User-Agent string. See #227. (@tarcieri)


## 0.8.10 (2015-05-14)

* Fix cookie headers generation. (@ixti)


## 0.8.9 (2015-05-11)

* Add cookies support. (@ixti)
* Enforce stringified body encoding. See #219. (@Connorhd)


## 0.8.8 (2015-05-09)

* Fix CONNECT header for proxies. See #217. (@Connorhd)


## 0.8.7 (2015-05-08)

* Fix `HTTP.timeout` API with options only given. (@ixti)


## 0.8.6 (2015-05-08)

* Reset global timeouts after the request finishes. See #215. (@zanker)


## 0.8.5 (2015-05-06)

* Add simple timeouts configuration API. See #205. (@ixti)
* Deprecate `Request#request_header`. Use `Request#headline` instead. (@ixti)


## 0.8.4 (2015-04-23)

* Deprecate `#default_headers` and `#default_headers=`. (@ixti)
* Deprecate chainable methods with `with_` prefix. See #207. (@ixti)
* Add support of HTTPS connections through proxy. See #186. (@Connorhd)


## 0.8.3 (2015-04-07)

* Fix request headline. See #206. (@ixti)
* Remove deprecated `Request#__method__`. (@ixti)


## 0.8.2 (2015-04-06)

* Fix Celluloid::IO compatibility. See #203. (@ixti)
* Cleanup obsolete code. (@zanker)


## 0.8.1 (2015-04-02)

* Add missing `require "resolv"`. See #202. (@ixti)
* Add block-form `#persistent` calls. See #200, #201. (@ixti)


## 0.8.0 (2015-04-01)

* Properly handle WaitWritable for SSL. See #199. (@zanker)
* Add support for non-ASCII URis. See #197. (@ixti)
* Add configurable connection timeouts. See #187, #194, #195. (@zanker)
* Refactor requests redirect following logic. See #179. (@ixti)
* Support for persistent HTTP connections (@zanker)
* Add caching support. See #77 and #177. (@Asmod4n, @pezra)
* Improve servers used in specs boot up. Issue was initially raised up
  by @olegkovalenko. See #176. (@ixti)
* Reflect FormData rename changes (FormData -> HTTP::FormData). (@ixti)
* `HTTP::Headers` now raises `HTTP::InvalidHeaderNameError` in case of
  (surprise) invalid HTTP header field name (e.g.`"Foo:Bar"`). See #173.
  (@ixti)


## 0.7.3 (2015-03-24)

* SECURITY FIX: http.rb failed to call the `#post_connection_check` method on
  SSL connections. This method implements hostname verification, and without it
  `http.rb` was vulnerable to MitM attacks. The problem was corrected by calling
  `#post_connection_check` (CVE-2015-1828) (@zanker)


## 0.7.2 (2015-03-02)

* Swap from `form_data` to `http-form_data` (changed gem name).


## 0.7.1 (2015-01-03)

* Gemspec fixups
* Remove superfluous space in HTTP::Response inspection


## 0.7.0 (2015-01-02)

* Add support of multipart form data. See #73, #167. (@ixti)
* Fix URI path normalization: `https://github.com` -> `https://github.com/`.
  (@ixti)
* Fix handling of EOF which caused infinite loop. See #163, #166 and #152. (@mickm, @ixti)
* Drop Ruby 1.8.7 support. (@ixti)
* Fix default Host header value. See #150. (@ixti)
* Remove BearerToken authorization header. (@ixti)
* `#auth` sugar now accepts only string value of Authorization header.
  Calling `#auth(:basic, opts)` is deprecated, use `#basic_auth(opts)` instead.
  (@ixti)
* Fix handling of chunked responses without Content-Length header. (@ixti)
* Remove `HTTP::Request#method` and deprecate `HTTP::Request#__method__`
  (@sferik)
* Deprecate `HTTP::Response::STATUS_CODES`,
  use `HTTP::Response::Status::REASONS` instead (@ixti)
* Deprecate `HTTP::Response::SYMBOL_TO_STATUS_CODE` (@ixti)
* Deprecate `HTTP::Response#status_code` (@ixti)
* `HTTP::Response#status` now returns `HTTP::Response::Status`. (@ixti)
* `HTTP::Response#reason` and `HTTP::Response#code` are proxies them
  to corresponding methods of `HTTP::Response#status` (@ixti)
* Rename `HTTP.with_follow` to `HTTP.follow` and mark former one as being
  deprecated (@ixti)
* Delegate `HTTP::Response#readpartial` to `HTTP::Response::Body` (@ixti)


## 0.6.4 (2015-03-25)

* SECURITY FIX: http.rb failed to call the `#post_connection_check` method on
  SSL connections. This method implements hostname verification, and without it
  `http.rb` was vulnerable to MitM attacks. The problem was corrected by calling
  `#post_connection_check` (CVE-2015-1828) (@zanker, backported by @nicoolas25)


## 0.6.3 (2014-11-14)

* Backported EOF fix from master branch. See #166. (@ixti)


## 0.6.2 (2014-08-06)

* Fix default Host header value. See #150. (@ixti)
* Deprecate BearerToken authorization header. (@ixti)
* Fix handling of chunked responses without Content-Length header. (@ixti)
* Rename `HTTP.with_follow` to `HTTP.follow` and mark former one as being
  deprecated (@ixti)


## 0.6.1 (2014-05-07)

* Fix request `Content-Length` calculation for Unicode (@challengeechallengee)
* Add `Response#flush` (@ixti)
* Fix `Response::Body#readpartial` default size (@hannesg, @ixti)
* Add missing `CRLF` for chunked bodies (@hannesg)
* Fix forgotten CGI require (@ixti)
* Improve README (@tarcieri)


## 0.6.0 (2014-04-04)

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

[Changes discussion](https://github.com/httprb/http.rb/issues/116)


## 0.5.1 (2014-05-27)

* Backports redirector fixes from 0.6.0 (@ixti)
* EOL of 0.5.X branch.


## 0.5.0 (2013-09-14)

* Add query string support
* New response delegator allows HTTP.get(uri).response
* HTTP::Chainable#stream provides a shorter alias for
  with_response(:object)
* Better string inspect for HTTP::Response
* Curb compatibility layer removed


## 0.4.0 (2012-10-12)

* Fix bug accessing https URLs
* Fix several instances of broken redirect handling
* Add default user agent
* Many additional minor bugfixes


## 0.3.0 (2012-09-01)

* New implementation based on tmm1's http_parser.rb instead of Net::HTTP
* Support for following redirects
* Support for request body through {:body => ...} option
* HTTP#with_response (through Chainable)


## 0.2.0 (2012-03-05)

* Request and response objects
* Callback system
* Internal refactoring ensuring true chainability
* Use the certified gem to ensure SSL certificate verification


## 0.1.0 (2012-01-26)

* Testing against WEBrick
* Curb compatibility (require 'http/compat/curb')


## 0.0.1 (2011-10-11)

* Initial half-baked release


## 0.0.0 (2011-10-06)

* Vapoware release to claim the "http" gem name >:D
