![The HTTP Gem](https://raw.github.com/tarcieri/http/master/logo.png)
==============
[![Gem Version](https://badge.fury.io/rb/http.png)](http://rubygems.org/gems/http)
[![Build Status](https://secure.travis-ci.org/tarcieri/http.png?branch=master)](http://travis-ci.org/tarcieri/http)
[![Code Climate](https://codeclimate.com/github/tarcieri/http.png)](https://codeclimate.com/github/tarcieri/http)
[![Coverage Status](https://coveralls.io/repos/tarcieri/http/badge.png?branch=master)](https://coveralls.io/r/tarcieri/http)

SEO Note
--------

This Gem has the worst name in the history of SEO. But perhaps we can fix that if we
all refer to it as "The HTTP Gem", or even better, the "Ruby HTTP Gem".

About
-----

The HTTP Gem is an easy-to-use client library for making requests from Ruby. It uses
a simple method chaining system for building requests, similar to Python's [Requests]

Under the hood, The HTTP Gem uses [http_parser.rb], a fast HTTP parsing native
extension based on the Node.js parser and a Java port thereof.

[requests]: http://docs.python-requests.org/en/latest/
[http_parser.rb]: https://github.com/tmm1/http_parser.rb

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

Documentation
-------------

[Please see the HTTP Gem Wiki](https://github.com/tarcieri/http/wiki)
for more detailed documentation and usage notes.

Support
-------

For help with The HTTP Gem, either open a [Github Issue] or discuss it
on the Celluloid mailing list:

http://groups.google.com/group/celluloid-ruby

You can also find us on IRC at #celluloid on freenode

[Github Issue]: https://github.com/tarcieri/http/issues

Basic Usage
-----------

Here's some simple examples to get you started:

### GET requests

```ruby
>> HTTP.get("http://www.google.com").to_s
=> "<html><head><meta http-equiv=\"content-type\" content=..."
```

That's all it takes! To obtain an `HTTP::Response` object instead of the response
body, all we have to do is omit the #to_s on the end:

```ruby
>> HTTP.get("http://www.google.com")
=> #<HTTP/1.0 200 OK @headers={"Content-Type"=>"text/html; charset=UTF-8", "Date"=>"Fri, ...>
 => #<HTTP::Response/1.1 200 OK @headers={"Content-Type"=>"text/html; ...>
```

We can also obtain an `HTTP::ResponseBody` object for this response:

```ruby
>> HTTP.get("http://www.google.com").body
 => #<HTTP::ResponseBody:814d7aac @streaming=false>
```

The response body can be streamed with `HTTP::ResponseBody#readpartial`:

```ruby
>> HTTP.get("http://www.google.com").body.readpartial
 => "<!doctype html><html "
```

In practice you'll want to bind the HTTP::ResponseBody to a local variable (e.g.
"body") and call readpartial on it repeatedly until it returns nil.

### POST requests

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
HTTP.post "http://example.com/resource", :json => { :foo => '42' })
```

It's easy!


### Proxy Support

Making request behind proxy is as simple as making them directly. Just specify
hostname (or IP address) of your proxy server and it's port, and here you go:

```ruby
HTTP.via("proxy-hostname.local", 8080)
  .get "http://example.com/resource"
```

Proxy needs authentication? No problem:

```ruby
HTTP.via("proxy-hostname.local", 8080, "username", "password")
  .get "http://example.com/resource"
```


### Adding Headers

The HTTP gem uses the concept of chaining to simplify requests. Let's say
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
JSON.parse, the HTTP gem will attempt to parse the JSON response.

Shorter aliases exists for HTTP.with_headers:

```ruby
HTTP.with(:accept => 'application/json').
  get("https://github.com/tarcieri/http/commit/HEAD")

HTTP[:accept => 'application/json'].
  get("https://github.com/tarcieri/http/commit/HEAD")
```

### Content Negotiation

As important a concept as content negotiation is to HTTP, it sure should be easy,
right? But usually it's not, and so we end up adding ".json" onto the ends of
our URLs because the existing mechanisms make it too hard. It should be easy:

```ruby
HTTP.accept(:json).get("https://github.com/tarcieri/http/commit/HEAD")
```

This adds the appropriate Accept header for retrieving a JSON response for the
given resource.


### Celluloid::IO Support

The HTTP Gem makes it simple to make multiple concurrent HTTP requests from a
Celluloid::IO actor. Here's a parallel HTTP fetcher with the HTTP Gem and
Celluloid::IO:

```ruby
require 'celluloid/io'
require 'http'

class HttpFetcher
  include Celluloid::IO

  def fetch(url)
    HTTP.get(url, socket_class: Celluloid::IO::TCPSocket).response
  end
end
```

There's a little more to it, but that's the core idea!

* [Full parallel HTTP fetcher example](https://github.com/tarcieri/http/wiki/Parallel-requests-with-Celluloid%3A%3AIO)
* See also: [Celluloid::IO](https://github.com/celluloid/celluloid-io)


Supported Ruby Versions
-----------------------

This library aims to support and is [tested against][travis] the following Ruby
versions:

* Ruby 1.8.7
* Ruby 1.9.2
* Ruby 1.9.3
* Ruby 2.0.0
* Ruby 2.1.0

If something doesn't work on one of these versions, it's a bug.

This library may inadvertently work (or seem to work) on other Ruby versions,
however support will only be provided for the versions listed above.

If you would like this library to support another Ruby version or
implementation, you may volunteer to be a maintainer. Being a maintainer
entails making sure all tests run and pass on that implementation. When
something breaks on your implementation, you will be responsible for providing
patches in a timely fashion. If critical issues for a particular implementation
exist at the time of a major release, support for that Ruby version may be
dropped.

[travis]: http://travis-ci.org/tarcieri/http


Contributing to The HTTP Gem
----------------------------

* Fork the HTTP gem on github
* Make your changes and send me a pull request
* If we like them we'll merge them
* If we've accepted a patch, feel free to ask for commit access!

Copyright
---------

Copyright (c) 2014 Tony Arcieri, Erik Michaels-Ober. See LICENSE.txt for further details.
