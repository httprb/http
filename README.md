# ![http.rb](https://raw.github.com/httprb/http.rb/main/logo.png)

[![Gem Version][gem-image]][gem-link]
[![MIT licensed][license-image]][license-link]
[![Docs][docs-image]][docs-link]
[![Lint][lint-image]][lint-link]
[![Mutant][mutant-image]][mutant-link]
[![Test][test-image]][test-link]
[![Typecheck][typecheck-image]][typecheck-link]

[Documentation]

## About

HTTP (The Gem! a.k.a. http.rb) is an easy-to-use client library for making requests
from Ruby. It uses a simple method chaining system for building requests, similar to
Python's [Requests].

Under the hood, http.rb uses the [llhttp] parser, a fast HTTP parsing native extension.
This library isn't just yet another wrapper around `Net::HTTP`. It implements the HTTP
protocol natively and outsources the parsing to native extensions.

### Why http.rb?

- **Clean API**: http.rb offers an easy-to-use API that should be a
   breath of fresh air after using something like Net::HTTP.

- **Maturity**: http.rb is one of the most mature Ruby HTTP clients, supporting
   features like persistent connections and fine-grained timeouts.

- **Performance**: using native parsers and a clean, lightweight implementation,
   http.rb achieves high performance while implementing HTTP in Ruby instead of C.


## Installation

Add this line to your application's Gemfile:
```ruby
gem "http"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install http
```

Inside of your Ruby program do:
```ruby
require "http"
```

...to pull it in as a dependency.


## Documentation

[Please see the http.rb wiki][documentation]
for more detailed documentation and usage notes.

The following API documentation is also available:

- [YARD API documentation](https://www.rubydoc.info/github/httprb/http)
- [Chainable module (all chainable methods)](https://www.rubydoc.info/github/httprb/http/HTTP/Chainable)


### Basic Usage

Here's some simple examples to get you started:

```ruby
>> HTTP.get("https://github.com").to_s
=> "\n\n\n<!DOCTYPE html>\n<html lang=\"en\" class=\"\">\n  <head prefix=\"o..."
```

That's all it takes! To obtain an `HTTP::Response` object instead of the response
body, all we have to do is omit the `#to_s` on the end:

```ruby
>> HTTP.get("https://github.com")
=> #<HTTP::Response/1.1 200 OK {"Server"=>"GitHub.com", "Date"=>"Tue, 10 May...>
```

We can also obtain an `HTTP::Response::Body` object for this response:

```ruby
>> HTTP.get("https://github.com").body
=> #<HTTP::Response::Body:3ff756862b48 @streaming=false>
```

The response body can be streamed with `HTTP::Response::Body#readpartial`.
In practice, you'll want to bind the `HTTP::Response::Body` to a local variable
and call `#readpartial` on it repeatedly until it returns `nil`:

```ruby
>> body = HTTP.get("https://github.com").body
=> #<HTTP::Response::Body:3ff756862b48 @streaming=false>
>> body.readpartial
=> "\n\n\n<!DOCTYPE html>\n<html lang=\"en\" class=\"\">\n  <head prefix=\"o..."
>> body.readpartial
=> "\" href=\"/apple-touch-icon-72x72.png\">\n    <link rel=\"apple-touch-ic..."
# ...
>> body.readpartial
=> nil
```

### Pattern Matching

Response objects support Ruby's pattern matching:

```ruby
case HTTP.get("https://api.example.com/users")
in { status: 200..299, body: body }
  JSON.parse(body.to_s)
in { status: 404 }
  nil
in { status: 400.. }
  raise "request failed"
end
```

Pattern matching is also supported on `HTTP::Response::Status`, `HTTP::Headers`,
`HTTP::ContentType`, and `HTTP::URI`.

### Base URI

Set a base URI to avoid repeating the scheme and host in every request:

```ruby
api = HTTP.base_uri("https://api.example.com/v1")
api.get("users")       # GET https://api.example.com/v1/users
api.get("users/1")     # GET https://api.example.com/v1/users/1
```

Relative paths are resolved per [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986#section-5).
Combine with `persistent` to reuse the connection:

```ruby
HTTP.base_uri("https://api.example.com/v1").persistent do |http|
  http.get("users")
  http.get("posts")
end
```

### Thread Safety

Configured sessions are safe to share across threads:

```ruby
# Build a session once, use it from any thread
session = HTTP.headers("Accept" => "application/json")
              .timeout(10)
              .auth("Bearer token")

threads = 10.times.map do
  Thread.new { session.get("https://example.com/api/data") }
end
threads.each(&:join)
```

Chainable configuration methods (`.headers`, `.timeout`, `.auth`, etc.) return
an `HTTP::Session`, which creates a fresh `HTTP::Client` for every request.

Persistent connections (`HTTP.persistent`) return an `HTTP::Session` that pools
one `HTTP::Client` per origin. The session itself is **not** thread-safe. For
thread-safe persistent connections, use the
[connection_pool](https://rubygems.org/gems/connection_pool) gem:

```ruby
pool = ConnectionPool.new(size: 5) { HTTP.persistent("https://example.com") }
pool.with { |http| http.get("/path") }
```

Cross-origin redirects are handled transparently — the session opens a separate
persistent connection for each origin encountered during a redirect chain:

```ruby
HTTP.persistent("https://example.com").follow do |http|
  http.get("/moved-to-other-domain")  # follows redirect across origins
end
```

## Supported Ruby Versions

This library aims to support and is [tested against][build-link]
the following Ruby  versions:

- Ruby 3.2
- Ruby 3.3
- Ruby 3.4
- Ruby 4.0

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


## Upgrading

See [UPGRADING.md] for a detailed migration guide between major versions.


## Security

See [SECURITY.md] for reporting vulnerabilities.


## Contributing to http.rb

See [CONTRIBUTING.md] for guidelines, or the quick version:

- Fork http.rb on GitHub
- Make your changes
- Ensure all tests pass (`bundle exec rake`)
- Send a pull request
- If we like them we'll merge them
- If we've accepted a patch, feel free to ask for commit access!


## Copyright

Copyright © 2011-2026 Tony Arcieri, Erik Berlin, Alexey V. Zapparov, Zachary Anker.
See LICENSE.txt for further details.


[//]: # (badges)

[gem-image]: https://img.shields.io/gem/v/http?logo=ruby
[gem-link]: https://rubygems.org/gems/http
[license-image]: https://img.shields.io/badge/license-MIT-blue.svg
[license-link]: https://github.com/httprb/http/blob/main/LICENSE.txt
[docs-image]: https://github.com/httprb/http/actions/workflows/docs.yml/badge.svg
[docs-link]: https://github.com/httprb/http/actions/workflows/docs.yml
[lint-image]: https://github.com/httprb/http/actions/workflows/lint.yml/badge.svg
[lint-link]: https://github.com/httprb/http/actions/workflows/lint.yml
[mutant-image]: https://github.com/httprb/http/actions/workflows/mutant.yml/badge.svg
[mutant-link]: https://github.com/httprb/http/actions/workflows/mutant.yml
[test-image]: https://github.com/httprb/http/actions/workflows/test.yml/badge.svg
[test-link]: https://github.com/httprb/http/actions/workflows/test.yml
[typecheck-image]: https://github.com/httprb/http/actions/workflows/typecheck.yml/badge.svg
[typecheck-link]: https://github.com/httprb/http/actions/workflows/typecheck.yml

[//]: # (links)

[contributing.md]: https://github.com/httprb/http/blob/main/CONTRIBUTING.md
[documentation]: https://github.com/httprb/http/wiki
[llhttp]: https://llhttp.org/
[requests]: https://docs.python-requests.org/en/latest/
[security.md]: https://github.com/httprb/http/blob/main/SECURITY.md
[upgrading.md]: https://github.com/httprb/http/blob/main/UPGRADING.md
