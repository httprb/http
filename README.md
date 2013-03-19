The Http Gem*
==============
[![Gem Version](https://badge.fury.io/rb/http.png)](http://rubygems.org/gems/http)
[![Build Status](https://secure.travis-ci.org/tarcieri/http.png?branch=master)](http://travis-ci.org/tarcieri/http)
[![Dependency Status](https://gemnasium.com/tarcieri/http.png)](https://gemnasium.com/tarcieri/http)
[![Code Climate](https://codeclimate.com/github/tarcieri/http.png)](https://codeclimate.com/github/tarcieri/http)
[![Coverage Status](https://coveralls.io/repos/tarcieri/http/badge.png?branch=master)](https://coveralls.io/r/tarcieri/http)

*NOTE: this gem has the worst name in the history of SEO. But perhaps we can fix
that if we all refer to it as "The HTTP Gem". Entering that phrase into Google
actually pulls it up as #4 for me!

The Http Gem is an easy-to-use client library for making requests from Ruby. It uses
a simple method chaining system for building requests, similar to libraries
like JQuery or Python's [Requests](http://docs.python-requests.org/en/latest/).

Installation
------------

Add this line to your application's Gemfile:

    gem 'http'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install http

Inside of your Ruby program do:

    require 'http'

...to pull it in as a dependency.

Making Requests
---------------

Let's start with getting things:

```ruby
>> Http.get("http://www.google.com")
=> "<html><head><meta http-equiv=\"content-type\" content=..."
```

That's it! The result is the response body as a string. To obtain an Http::Response object
instead of the response body, chain `.response` on the end of the request:

```ruby
>> Http.get("http://www.google.com").response
=> #<HTTP/1.0 200 OK @headers={"Content-Type"=>"text/html; charset=UTF-8", "Date"=>"Fri, ...>
```

Making POST requests is simple too. Want to POST a form?

```ruby
Http.post "http://example.com/resource", :form => {:foo => "42"}
```

Want to POST with a specific body, JSON for instance?

```ruby
Http.post "http://example.com/resource", :body => JSON.dump(:foo => '42')
```

Or have it serialize JSON for you:

```ruby
Http.post "http://example.com/resource", :json => {:foo => '42'}
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

Copyright (c) 2013 Tony Arcieri. See LICENSE.txt for further details.
