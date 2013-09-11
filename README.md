The HTTP Gem*
==============
[![Gem Version](https://badge.fury.io/rb/http.png)](http://rubygems.org/gems/http)
[![Build Status](https://secure.travis-ci.org/tarcieri/http.png?branch=master)](http://travis-ci.org/tarcieri/http)
[![Code Climate](https://codeclimate.com/github/tarcieri/http.png)](https://codeclimate.com/github/tarcieri/http)
[![Coverage Status](https://coveralls.io/repos/tarcieri/http/badge.png?branch=master)](https://coveralls.io/r/tarcieri/http)

*NOTE: this gem has the worst name in the history of SEO. But perhaps we can fix
that if we all refer to it as "The HTTP Gem". Entering that phrase into Google
actually pulls it up as #4 for me!

The HTTP Gem is an easy-to-use client library for making requests from Ruby. It uses
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
>> HTTP.get("http://www.google.com")
=> "<html><head><meta http-equiv=\"content-type\" content=..."
```

That's it! The result is the response body as a string. To obtain an HTTP::Response object
instead of the response body, chain `.response` on the end of the request:

```ruby
>> HTTP.get("http://www.google.com").response
=> #<HTTP/1.0 200 OK @headers={"Content-Type"=>"text/html; charset=UTF-8", "Date"=>"Fri, ...>
```

Making POST requests is simple too. Want to POST a form?

```ruby
HTTP.post "http://example.com/resource", :form => {:foo => "42"}
```
Making GET requests with query string parameters is as simple.

```ruby
HTTP.get "http://example.com/resource", :params => {:foo => "bar"}
```

Want to POST with a specific body, JSON for instance?

```ruby
HTTP.post "http://example.com/resource", :body => JSON.dump(:foo => '42')
```

Or have it serialize JSON for you:

```ruby
HTTP.post "http://example.com/resource", :json => {:foo => '42'}
```

It's easy!

Adding Headers
--------------

The HTTP library uses the concept of chaining to simplify requests. Let's say
you want to get the latest commit of this library from Github in JSON format.
One way we could do this is by tacking a filename on the end of the URL:

```ruby
HTTP.get "https://github.com/tarcieri/http/commit/HEAD.json"
```

The Github API happens to support this approach, but really this is a bit of a
hack that makes it easy for people typing URLs into the address bars of
browsers to perform the act of content negotiation. Since we have access to
the full, raw power of HTTP, we can perform content negotiation the way HTTP
intends us to, by using the Accept header:

```ruby
HTTP.with_headers(:accept => 'application/json').
  get("https://github.com/tarcieri/http/commit/HEAD")
```

This requests JSON from Github. Github is smart enough to understand our
request and returns a response with Content-Type: application/json. If you
happen to have a library loaded which defines the JSON constant and implements
JSON.parse, the HTTP library will attempt to parse the JSON response.

Shorter aliases exists for HTTP.with_headers:

```ruby
HTTP.with(:accept => 'application/json').
  get("https://github.com/tarcieri/http/commit/HEAD")

HTTP[:accept => 'application/json'].
  get("https://github.com/tarcieri/http/commit/HEAD")
```

Content Negotiation
-------------------

As important a concept as content negotiation is HTTP, it sure should be easy,
right? But usually it's not, and so we end up adding ".json" onto the ends of
our URLs because the existing mechanisms make it too hard. It should be easy:

```ruby
HTTP.accept(:json).get("https://github.com/tarcieri/http/commit/HEAD")
```

This adds the appropriate Accept header for retrieving a JSON response for the
given resource.

Contributing to HTTP
--------------------

* Fork HTTP on github
* Make your changes and send me a pull request
* If I like them I'll merge them
* If I've accepted a patch, feel free to ask for a commit bit!

Copyright
---------

Copyright (c) 2013 Tony Arcieri. See LICENSE.txt for further details.
