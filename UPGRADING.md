# Upgrading to HTTP.rb 6.0

This guide covers all breaking changes between v5.x and v6.0 and shows how to
update your code.

## Ruby version

**v6 requires Ruby 3.2+.** Drop support for Ruby 2.x and 3.0/3.1.

## Quick reference

| What changed | v5 | v6 |
|---|---|---|
| Chainable return type | `HTTP::Client` | `HTTP::Session` |
| `HTTP.persistent` return type | `HTTP::Client` | `HTTP::Session` (pools per origin) |
| `.retriable` return type | `HTTP::Retriable::Client` | `HTTP::Session` |
| `response.cookies` | `HTTP::CookieJar` | `Array<HTTP::Cookie>` |
| `response["Header"]` | Works (via `Headers::Mixin`) | Removed — use `response.headers["Header"]` |
| `request["Header"]` | Works (via `Headers::Mixin`) | Removed — use `request.headers["Header"]` |
| `status.even?`, `status.zero?`, etc. | Works (via `Delegator`) | Removed — use `status.code.even?` |
| `build_request` | On `Client`, `Session`, `HTTP` | Removed — use `HTTP::Request::Builder` |
| Options API | Accepts `Hash` or keywords | Keywords only |
| `addressable` gem | Required dependency | Optional (only for non-ASCII URIs) |
| `URI` setters (`scheme=`, etc.) | Available | Removed |
| `URI#join`, `URI#omit` | Returns `Addressable::URI` | Returns `HTTP::URI` |
| `readpartial` at EOF | Returns `nil` | Raises `EOFError` |
| Timeout defaults | 0.25s for omitted operations | No timeout for omitted operations |
| Global + per-op timeouts | Mutually exclusive | Can be combined |

---

## Breaking changes in detail

### 1. Chainable methods return `HTTP::Session` instead of `HTTP::Client`

All chainable configuration methods (`.headers`, `.timeout`, `.cookies`, `.auth`,
`.follow`, `.via`, `.use`, `.encoding`, `.nodelay`, `.basic_auth`, `.accept`)
now return a thread-safe `HTTP::Session` instead of `HTTP::Client`.

`Session` creates a fresh `Client` for each request, making it safe to share
across threads. The HTTP verb methods (`.get`, `.post`, etc.) and
`.default_options` work the same way.

```ruby
# v5
client = HTTP.headers("Accept" => "application/json")
client.is_a?(HTTP::Client) # => true

# v6
session = HTTP.headers("Accept" => "application/json")
session.is_a?(HTTP::Session) # => true
session.get("https://example.com") # works the same
```

**Action:** Update any `is_a?(HTTP::Client)` checks on the return value of
chainable methods to check for `HTTP::Session`.

### 2. `HTTP.persistent` returns `HTTP::Session` with connection pooling

`HTTP.persistent` now returns an `HTTP::Session` that pools one persistent
`HTTP::Client` per origin. This means cross-origin redirects work automatically
instead of raising `StateError`.

```ruby
# v5
client = HTTP.persistent("https://api.example.com")
client.is_a?(HTTP::Client) # => true
# Cross-origin redirects raise StateError

# v6
session = HTTP.persistent("https://api.example.com")
session.is_a?(HTTP::Session) # => true
# Cross-origin redirects work — each origin gets its own connection
session.close # shuts down all pooled connections
```

Chaining on a persistent session now shares the connection pool:

```ruby
# v5 — this broke connection reuse
HTTP.persistent("https://api.example.com").headers("X-Token" => "abc").get("/users")

# v6 — works correctly, shares the parent's connection pool
HTTP.persistent("https://api.example.com").headers("X-Token" => "abc").get("/users")
```

### 3. `.retriable` returns `HTTP::Session` instead of `HTTP::Retriable::Client`

Retry is now a session-level option. The `HTTP::Retriable::Client` and
`HTTP::Retriable::Session` classes no longer exist.

```ruby
# v5
client = HTTP.retriable(tries: 3)
client.is_a?(HTTP::Retriable::Client) # => true

# v6
session = HTTP.retriable(tries: 3)
session.is_a?(HTTP::Session) # => true
session.get("https://example.com") # retries up to 3 times
```

### 4. Options hashes replaced with keyword arguments

Methods across the public API now require keyword arguments. Passing an explicit
`Hash` as a positional argument no longer works, and unrecognized keywords raise
`ArgumentError`.

```ruby
# v5 — both work
HTTP.get("https://example.com", body: "data")
HTTP.get("https://example.com", {body: "data"})

opts = {body: "data", headers: {"Content-Type" => "text/plain"}}
HTTP.get("https://example.com", opts)

# v6 — keywords only
HTTP.get("https://example.com", body: "data")

opts = {body: "data", headers: {"Content-Type" => "text/plain"}}
HTTP.get("https://example.com", **opts) # note the double-splat
```

This applies to constructors too:

```ruby
# v5
HTTP::Options.new({response: :body})
HTTP::Client.new({timeout_class: HTTP::Timeout::Global})

# v6
HTTP::Options.new(response: :body)
HTTP::Client.new(timeout_class: HTTP::Timeout::Global)

# If you have an options hash, use double-splat:
opts = {response: :body}
HTTP::Options.new(**opts)
```

Affected methods: all HTTP verb methods, `request`, `follow`, `retriable`,
`URI.new`, `Request.new`, `Response.new`, `Options.new`, `Client.new`,
`Session.new`.

### 5. `Headers::Mixin` removed — no more `[]`/`[]=` on Request and Response

`Request` and `Response` no longer include `Headers::Mixin`, so you can't use
bracket access directly on them.

```ruby
# v5
response = HTTP.get("https://example.com")
response["Content-Type"]            # => "text/html"
request["Authorization"] = "Bearer token"

# v6
response = HTTP.get("https://example.com")
response.headers["Content-Type"]    # => "text/html"
request.headers["Authorization"] = "Bearer token"
```

### 6. `Response#cookies` returns `Array` instead of `CookieJar`

```ruby
# v5
response.cookies                    # => #<HTTP::CookieJar ...>
response.cookies.each { |cookie| puts cookie.name }
jar = response.cookies
jar["session_id"]                   # CookieJar lookup

# v6
response.cookies                    # => [#<HTTP::Cookie ...>, ...]
response.cookies.each { |cookie| puts cookie.name }
cookie = response.cookies.find { |c| c.name == "session_id" }
```

The `cookies` chainable option also changed — the last `.cookies()` call wins
(no implicit merging):

```ruby
# v5 — cookies merged across calls
HTTP.cookies(a: "1").cookies(b: "2") # sends both a=1 and b=2

# v6 — last call wins
HTTP.cookies(a: "1").cookies(b: "2") # sends only b=2
HTTP.cookies(a: "1", b: "2")         # sends both a=1 and b=2
```

### 7. `Response::Status` no longer delegates to `Integer`

`Status` is no longer a `Delegator` subclass. It uses `Comparable` and
`Forwardable` instead, providing `to_i`, `to_int`, `<=>`, and named predicates.

```ruby
status = response.status

# Still works in v6
status.to_i          # => 200
status == 200        # => true (via Comparable + to_int)
(200..299).cover?(status) # => true (via to_int)
status.ok?           # => true
status.success?      # => true
status.to_s          # => "200 OK"
status.code          # => 200
status.reason        # => "OK"

# v5 only — breaks in v6
status.even?         # NoMethodError — use status.code.even?
status.between?(200, 299) # NoMethodError — use status.code.between?(200, 299)
status + 1           # NoMethodError — use status.code + 1
status.__getobj__    # NoMethodError — use status.code
```

**Action:** Replace any direct `Integer` method calls on status objects with
`status.code.<method>`.

### 8. `build_request` removed — use `HTTP::Request::Builder`

The `build_request` method has been removed from `Client`, `Session`, and the
top-level `HTTP` module.

```ruby
# v5
request = HTTP.build_request(:get, "https://example.com")
request = HTTP.headers("Accept" => "application/json")
              .build_request(:post, "https://example.com", json: {name: "test"})

# v6
options = HTTP::Options.new(headers: {"Accept" => "application/json"},
                            json: {name: "test"})
builder = HTTP::Request::Builder.new(options)
request = builder.build(:post, "https://example.com")
```

### 9. `readpartial` raises `EOFError` instead of returning `nil`

`Connection#readpartial`, `Body#readpartial`, and `Inflater#readpartial` now
raise `EOFError` at end-of-stream instead of returning `nil`, conforming to
Ruby's `IO#readpartial` contract.

```ruby
# v5
loop do
  chunk = response.body.readpartial
  break if chunk.nil?
  process(chunk)
end

# v6
loop do
  chunk = response.body.readpartial
  process(chunk)
rescue EOFError
  break
end

# Or use the simpler iterator API (works in both versions):
response.body.each { |chunk| process(chunk) }
```

### 10. Timeout behavior changes

#### No more 0.25s default for omitted per-operation timeouts

```ruby
# v5 — omitted operations default to 0.25s
HTTP.timeout(read: 30).get(url)
# write and connect timeouts are 0.25s

# v6 — omitted operations have no timeout
HTTP.timeout(read: 30).get(url)
# write and connect have no timeout limit
```

**Action:** If you relied on the implicit 0.25s timeout, set all three
operations explicitly:

```ruby
HTTP.timeout(read: 0.25, write: 0.25, connect: 0.25).get(url)
```

#### Stricter timeout options parsing

```ruby
# v6 — rejects unknown keys
HTTP.timeout(read: 5, keep_alive: 10)
# => ArgumentError: unknown timeout options: keep_alive

# v6 — rejects mixed short/long forms
HTTP.timeout(read: 5, write_timeout: 3)
# => ArgumentError (use one form consistently)

# Valid in v6
HTTP.timeout(read: 5, write: 3, connect: 2)
HTTP.timeout(read_timeout: 5, write_timeout: 3, connect_timeout: 2)
```

#### Global and per-operation timeouts can be combined

```ruby
# v5 — mutually exclusive, raises ArgumentError
HTTP.timeout(global: 60, read: 30)

# v6 — works: 60s overall, 30s max per read, 10s max per write, 5s max per connect
HTTP.timeout(global: 60, read: 30, write: 10, connect: 5)
```

### 11. `addressable` is no longer a runtime dependency

`addressable` is lazy-loaded only when parsing non-ASCII (IRI) URIs. If your
code uses non-ASCII characters in URIs, add `addressable` to your Gemfile:

```ruby
# Gemfile
gem "addressable"
```

ASCII-only URIs use Ruby's stdlib `URI` parser exclusively and do not need
`addressable`.

### 12. `HTTP::URI` API changes

#### Removed setter methods

URI objects are now effectively immutable. Setter methods (`scheme=`, `host=`,
`port=`, `path=`, `query=`, `fragment=`, `user=`, `password=`, etc.) have been
removed.

```ruby
# v5
uri = HTTP::URI.parse("https://example.com")
uri.scheme = "http"
uri.path = "/api"

# v6 — construct a new URI instead
uri = HTTP::URI.parse("http://example.com/api")
```

#### `join` and `omit` now return `HTTP::URI`

```ruby
# v5
uri = HTTP::URI.parse("https://example.com")
joined = uri.join("/path")
joined.is_a?(Addressable::URI) # => true

# v6
joined = uri.join("/path")
joined.is_a?(HTTP::URI)        # => true
```

#### Removed `query_values` / `query_values=`

```ruby
# v5
uri.query_values = {"page" => "1", "per" => "10"}
uri.query_values # => {"page" => "1", "per" => "10"}

# v6 — use stdlib
uri = HTTP::URI.parse("https://example.com")
query = URI.encode_www_form(page: 1, per: 10)
uri = HTTP::URI.parse("https://example.com?#{query}")

# or use the params option:
HTTP.get("https://example.com", params: {page: 1, per: 10})
```

#### Removed `form_encode`

```ruby
# v5
HTTP::URI.form_encode(page: 1, per: 10)

# v6
URI.encode_www_form(page: 1, per: 10)
```

#### `HTTP::URI.new` no longer accepts `Addressable::URI`

```ruby
# v5
addr = Addressable::URI.parse("https://example.com")
HTTP::URI.new(addr) # works

# v6
HTTP::URI.new(addr) # ArgumentError
HTTP::URI.parse("https://example.com") # use parse instead
```

### 13. Error class changes

#### Malformed URI errors

```ruby
# v5
HTTP.get("not a uri")
# => HTTP::UnsupportedSchemeError or Addressable::URI::InvalidURIError

# v6
HTTP.get("not a uri")
# => HTTP::URI::InvalidError (for malformed URIs)

HTTP.get(nil)
# => ArgumentError (for nil/empty URIs)
```

#### New `ConnectionError` subclasses

`ConnectionError` now has more specific subclasses for targeted rescue:

- `HTTP::ResponseHeaderError` — header parsing failed
- `HTTP::SocketReadError` — socket read failed
- `HTTP::SocketWriteError` — socket write failed

```ruby
# v5
rescue HTTP::ConnectionError => e
  # all connection errors

# v6 — you can be more specific
rescue HTTP::SocketReadError => e
  # only read failures
rescue HTTP::ConnectionError => e
  # still catches all connection errors (superclass)
```

### 14. Security: credential stripping on cross-origin redirects

`Authorization` and `Cookie` headers are now automatically stripped when
following redirects to a different origin (scheme + host + port). This is a
security improvement, but may break code that intentionally sends credentials
across origins.

---

## New features (non-breaking)

These are new in v6 and require no migration, but are worth knowing about:

### Block form for verb methods

Auto-closes the connection after the block returns:

```ruby
body = HTTP.get("https://example.com") do |response|
  response.body.to_s
end
```

### `HTTP.base_uri`

Set a base URI for relative paths:

```ruby
api = HTTP.base_uri("https://api.example.com/v1")
api.get("users")   # GET https://api.example.com/v1/users
api.get("posts")   # GET https://api.example.com/v1/posts
```

### HTTP Digest Authentication

```ruby
HTTP.digest_auth(user: "admin", pass: "secret").get("https://example.com/protected")
```

### HTTP Caching (RFC 7234)

```ruby
HTTP.use(:caching).get("https://example.com") # caches with in-memory store
```

### Pattern matching

```ruby
case response
in { status: { code: 200..299 }, content_type: { mime_type: "application/json" } }
  response.parse
in { status: { code: 404 } }
  nil
end
```

### `Feature#on_request` and `Feature#around_request` hooks

New feature lifecycle hooks called before/around each request attempt (including
retries), useful for instrumentation and circuit breakers.

### `PURGE` HTTP method

```ruby
HTTP.request(:purge, "https://cdn.example.com/asset")
```
