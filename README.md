Http
====

Ruby has always been this extremely web-focused language, and yet despite the
selection of HTTP libraries out there, I always find myself falling back on
Net::HTTP, and Net::HTTP sucks.

Ruby should be simple and elegant and beautiful. Net::HTTP is not. I've often
found myself falling back on the Perlish horrors of open-uri just because I
found Net::HTTP to be too much of a pain. This shouldn't be!

HTTP should be simple and easy! It should be so straightforward it makes
you happy with how delightful it is to use!

Making Requests
---------------

Let's start with getting things:

```ruby
Http.get "http://www.google.com"
```

That's it! The result is the response body.

Don't like "Http"? No worries, this works as well:

```ruby
HTTP.get "http://www.google.com"
```

After all, There Is More Than One Way To Do It!

Making POST requests is simple too. Want to POST a form?

```ruby
Http.post "http://example.com/resource", :form => {:foo => "42"}
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

A shorter alias exists for HTTP.with_headers:

```ruby
Http.with(:accept => 'application/json').
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

Contributing to Http
--------------------

* Fork Http on github
* Make your changes and send me a pull request
* If I like them I'll merge them and give you commit access to my repository

Copyright
---------

Copyright (c) 2011 Tony Arcieri, Carl Lerche. See LICENSE.txt for further details.
