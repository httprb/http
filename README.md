Http
====
[![Build Status](https://secure.travis-ci.org/tarcieri/http.png?branch=master)](http://travis-ci.org/tarcieri/http)

HTTP should be simple and easy! It should be so straightforward it makes
you happy every time you use it.

The Http library makes it easy to construct requests using a simple chaining system.

Making Requests
---------------

Let's start with getting things:

```ruby
Http.get "http://www.google.com"
```

That's it! The result is the response body.

Making POST requests is simple too. Want to POST a form?

```ruby
Http.post "http://example.com/resource", :form => {:foo => "42"}
```

Want to POST with a specific body, JSON for instance?
```ruby
Http.post "http://example.com/resource", :body => JSON.dump(:foo => "42")
```

It's easy!

Adding Headers
--------------

The Http library uses the concept of chaining to simplify requests. Let's say
you want to get the latest commit of this library from Github in JSON format.
One way we could do this is by tacking a filename on the end of the URL:

```ruby
Http.get "https://github.com/tarcieri/http/commit/HEAD.json"
```

The Github API happens to support this approach, but really this is a bit of a
hack that makes it easy for people typing URLs into the address bars of
browsers to perform the act of content negotiation. Since we have access to
the full, raw power of HTTP, we can perform content negotiation the way HTTP
intends us to, by using the Accept header:

```ruby
Http.with_headers(:accept => 'application/json').
  get("https://github.com/tarcieri/http/commit/HEAD")
```

This requests JSON from Github. Github is smart enough to understand our
request and returns a response with Content-Type: application/json. If you
happen to have a library loaded which defines the JSON constant and implements
JSON.parse, the Http library will attempt to parse the JSON response.

Shorter aliases exists for HTTP.with_headers:

```ruby
Http.with(:accept => 'application/json').
  get("https://github.com/tarcieri/http/commit/HEAD")

Http[:accept => 'application/json'].
  get("https://github.com/tarcieri/http/commit/HEAD")
```

Content Negotiation
-------------------

As important a concept as content negotiation is HTTP, it sure should be easy,
right? But usually it's not, and so we end up adding ".json" onto the ends of
our URLs because the existing mechanisms make it too hard. It should be easy:

```ruby
Http.accept(:json).get("https://github.com/tarcieri/http/commit/HEAD")
```

This adds the appropriate Accept header for retrieving a JSON response for the
given resource.

Curb Compatibility
------------------

The Http gem provides partial compatibility with the Curb::Easy API. This is
great if you're transitioning to JRuby and need a drop-in API-compatible
replacement for Curb.

To use the Curb compatibility, do:

```ruby
require 'http/compat/curb'
```

Contributing to Http
--------------------

* Fork Http on github
* Make your changes and send me a pull request
* If I like them I'll merge them
* If I've accepted a patch, feel free to ask for a commit bit!

Copyright
---------

Copyright (c) 2011 Tony Arcieri, Carl Lerche. See LICENSE.txt for further details.
