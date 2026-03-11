# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- HTTP 1xx informational responses (e.g. `100 Continue`) are now transparently
  skipped, returning the final response. This was a regression introduced when
  the parser was migrated from http-parser to llhttp. ([#667])
- Redirect loop detection now considers cookies, so a redirect back to the
  same URL with different cookies is no longer falsely detected as an endless
  loop. Fixes cookie-dependent redirect flows where a server sets a cookie on
  one hop and expects it on the next. ([#544])
- Per-operation timeouts (`HTTP.timeout(read: n, write: n, connect: n)`) no
  longer default unspecified values to 0.25 seconds. Omitted timeouts now mean
  no timeout for that operation, matching the behavior when no timeout is
  configured at all. ([#579])

### Changed

- **BREAKING** Convert options hash parameters to explicit keyword arguments
  across the public API. Methods like `HTTP.get(url, body: "data")` continue to
  work, but passing an explicit hash (e.g., `HTTP.get(url, {body: "data"})`) is
  no longer supported, and unrecognized keyword arguments now raise
  `ArgumentError`. Affected methods: all HTTP verb methods (`get`, `post`,
  etc.), `request`, `follow`, `retriable`, `URI.new`, `Request.new`,
  `Response.new`, `Redirector.new`, `Retriable::Performer.new`,
  `Retriable::DelayCalculator.new`, and `Timeout::Null.new` (and subclasses).
  `HTTP::URI.new` also no longer accepts `Addressable::URI` objects.
- **BREAKING** `addressable` is no longer a runtime dependency. It is now
  lazy-loaded only when parsing non-ASCII (IRI) URIs or normalizing
  internationalized hostnames. Install the `addressable` gem if you need
  non-ASCII URI support. ASCII-only URIs use Ruby's stdlib `URI` parser
  exclusively.
- **BREAKING** Extract request building into `HTTP::Request::Builder`. The
  `build_request` method has been removed from `Client`, `Session`, and the
  top-level `HTTP` module. Use `HTTP::Request::Builder.new(options).build(verb, uri)`
  to construct requests without executing them.

### Added

- `HTTP.digest_auth(user:, pass:)` for HTTP Digest Authentication (RFC 2617 /
  RFC 7616). Automatically handles 401 challenges with digest credentials,
  supporting MD5, SHA-256, MD5-sess, and SHA-256-sess algorithms with
  quality-of-protection negotiation. Works as a chainable feature:
  `HTTP.digest_auth(user: "admin", pass: "secret").get(url)` ([#448])
- `HTTP.base_uri` for setting a base URI that resolves relative request paths
  per RFC 3986. Supports chaining (`HTTP.base_uri("https://api.example.com/v1")
  .get("users")`), and integrates with `persistent` connections by deriving the
  host when omitted (#519, #512, #493)
- `Request::Body#loggable?` and `Response::Body#loggable?` predicates, and a
  `binary_formatter` option for the logging feature. Binary bodies
  (IO/Enumerable request sources, binary-encoded request strings, and
  binary-encoded responses) are now formatted instead of dumped raw,
  preventing unreadable log output when transferring files like images or
  audio. Available formatters: `:stats` (default, logs byte count),
  `:base64` (logs base64-encoded content), or a custom `Proc`. Invalid
  formatter values raise `ArgumentError` (#784)
- `Feature#on_request` and `Feature#around_request` lifecycle hooks, called
  before/around each request attempt (including retries), for per-attempt side
  effects like instrumentation spans and circuit breakers (#826)
- Pattern matching support (`deconstruct_keys`) for Response, Response::Status,
  Headers, ContentType, and URI (#642)
- Combined global and per-operation timeouts: global and per-operation timeouts
  are no longer mutually exclusive. Use
  `HTTP.timeout(global: 60, read: 30, write: 30, connect: 5)` to set both a
  global request timeout and individual operation limits (#773)

### Fixed

- `HTTP::URI.form_encode` now encodes newlines as `%0A` instead of
  `%0D%0A` (#449)
- Thread-safety: `Headers::Normalizer` cache is now per-thread via
  `Thread.current`, eliminating a potential race condition when multiple
  threads share a normalizer instance
- Instrumentation feature now correctly starts a new span for each retry
  attempt, fixing `NoMethodError` with `ActiveSupport::Notifications` when
  using `.retriable` with the instrumentation feature (#826)
- Raise `HTTP::URI::InvalidError` for malformed or schemeless URIs and
  `ArgumentError` for nil or empty URIs, instead of confusing
  `UnsupportedSchemeError` or `Addressable::URI::InvalidURIError` (#565)
- Strip `Authorization` header when following redirects to a different origin
  (scheme, host, or port) to prevent credential leakage (#770)
- AutoInflate now preserves the response charset encoding instead of
  defaulting to `Encoding::BINARY` (#535)
- `LocalJumpError` when using instrumentation with instrumenters that
  unconditionally yield in `#instrument` (e.g., `ActiveSupport::Notifications`)
  (#673)
- Logging feature no longer eagerly consumes the response body at debug level;
  body chunks are now logged as they are streamed, preserving
  `response.body.each` (#785)

### Removed

- `HTTP::URI` setter methods (`scheme=`, `user=`, `password=`, `authority=`,
  `origin=`, `port=`, `request_uri=`, `fragment=`) and normalized accessors
  (`normalized_user`, `normalized_password`, `normalized_port`,
  `normalized_path`, `normalized_query`) that were delegated to
  `Addressable::URI` but never used internally
- `HTTP::URI#origin` is no longer delegated to `Addressable::URI`. The new
  implementation follows RFC 6454, normalizing scheme and host to lowercase
  and excluding user info from the origin string
- `HTTP::URI#request_uri` is no longer delegated to `Addressable::URI`
- `HTTP::URI#omit` is no longer delegated to `Addressable::URI` and now
  returns `HTTP::URI` instead of `Addressable::URI` (#491)
- `HTTP::URI#query_values` and `HTTP::URI#query_values=` delegations to
  `Addressable::URI`. Query parameter merging now uses stdlib
  `URI.decode_www_form`/`URI.encode_www_form`
- `HTTP::URI` delegations for `normalized_scheme`, `normalized_authority`,
  `normalized_fragment`, and `authority` to `Addressable::URI`. The URI
  normalizer now inlines these operations directly
- `HTTP::URI#join` is no longer delegated to `Addressable::URI` and now
  returns `HTTP::URI` instead of `Addressable::URI`. Uses stdlib `URI.join`
  with automatic percent-encoding of non-ASCII characters (#491)
- `HTTP::URI.form_encode` no longer delegates to `Addressable::URI`. Uses
  stdlib `URI.encode_www_form` instead

### Changed

- **BREAKING** `HTTP::Response::Status` no longer inherits from `Delegator`.
  It now uses `Comparable` and `Forwardable` instead, providing `to_i`,
  `to_int`, and `<=>` for numeric comparisons and range matching. Code that
  called `__getobj__`/`__setobj__` or relied on implicit delegation of
  arbitrary `Integer` methods (e.g., `status.even?`) will need to be updated
  to use `status.code` instead
- **BREAKING** Chainable option methods (`.headers`, `.timeout`, `.cookies`,
  `.auth`, `.follow`, `.via`, `.use`, `.encoding`, `.nodelay`, `.basic_auth`,
  `.accept`) now return a thread-safe `HTTP::Session` instead of `HTTP::Client`.
  `Session` creates a new `Client` for each request, making it safe to share a
  configured session across threads. `HTTP.persistent` still returns
  `HTTP::Client` since persistent connections require mutable state. Code that
  calls HTTP verb methods (`.get`, `.post`, etc.) or accesses `.default_options`
  is unaffected. Code that checks `is_a?(HTTP::Client)` on the return value of
  chainable methods will need to be updated to check for `HTTP::Session`
- **BREAKING** `.retriable` now returns `HTTP::Session` instead of
  `HTTP::Retriable::Client`. Retry is a session-level option: it flows through
  `HTTP::Options` into `HTTP::Client#perform`, eliminating the need for
  separate `Retriable::Client` and `Retriable::Session` classes
- Improved error message when request body size cannot be determined to suggest
  setting `Content-Length` explicitly or using chunked `Transfer-Encoding` (#560)
- **BREAKING** `Connection#readpartial` now raises `EOFError` instead of
  returning `nil` at end-of-stream, and supports an `outbuf` parameter,
  conforming to the `IO#readpartial` API. `Body#readpartial` and
  `Inflater#readpartial` also raise `EOFError` (#618)
- **BREAKING** Stricter timeout options parsing: `.timeout()` with a Hash now
  rejects unknown keys, non-numeric values, string keys, and empty hashes (#754)
- Bumped min llhttp dependency version
- **BREAKING** Handle responses in the reverse order from the requests (#776)
- **BREAKING** `Response#cookies` now returns `Array<HTTP::Cookie>` instead of
  `HTTP::CookieJar`. The `cookies` option has been removed from `Options`;
  `Chainable#cookies` now sets the `Cookie` header directly with no implicit
  merging — the last `.cookies()` call wins (#536)
- Cookie jar management during redirects moved from `Redirector` to `Session`.
  `Redirector` is now a pure redirect-following engine with no cookie
  awareness; `Session#request` manages cookies across redirect hops
- **BREAKING** `HTTP::Options.new`, `HTTP::Client.new`, and `HTTP::Session.new`
  now accept keyword arguments instead of an options hash. For example,
  `HTTP::Options.new(response: :body)` continues to work, but
  `HTTP::Options.new({response: :body})` must be updated to
  `HTTP::Options.new(**options)`. Invalid option names now raise
  `ArgumentError` automatically (#447)

### Removed

- **BREAKING** Drop Ruby 2.x support
- **BREAKING** Remove `Headers::Mixin` and the `[]`/`[]=` delegators on
  `Request` and `Response`. Use `request.headers["..."]` and
  `response.headers["..."]` instead (#537)

[unreleased]: https://github.com/httprb/http/compare/v5.3.0...main
