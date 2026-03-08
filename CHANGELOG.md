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

- AutoInflate now preserves the response charset encoding instead of
  defaulting to `Encoding::BINARY` (#535)

### Changed

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

### Removed

- **BREAKING** Drop Ruby 2.x support

[unreleased]: https://github.com/httprb/http/compare/v5.3.0...main
