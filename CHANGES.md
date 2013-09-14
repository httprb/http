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
