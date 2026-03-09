# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Pattern matching support (`deconstruct_keys`) for Response, Response::Status,
  Headers, ContentType, and URI (#642)
- Combined global and per-operation timeouts: global and per-operation timeouts
  are no longer mutually exclusive. Use
  `HTTP.timeout(global: 60, read: 30, write: 30, connect: 5)` to set both a
  global request timeout and individual operation limits (#773)

### Fixed

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

### Changed

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
