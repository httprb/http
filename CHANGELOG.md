# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Pattern matching support (`deconstruct_keys`) for Response, Response::Status,
  Headers, ContentType, and URI (#642)

### Changed

- **BREAKING** Stricter timeout options parsing: `.timeout()` with a Hash now
  rejects unknown keys, non-numeric values, string keys, and empty hashes.
  `HTTP.timeout(global: N)` is no longer accepted; use `HTTP.timeout(N)` (#754)
- Bumped min llhttp dependency version
- **BREAKING** Handle responses in the reverse order from the requests (#776)

### Removed

- **BREAKING** Drop Ruby 2.x support

[unreleased]: https://github.com/httprb/http/compare/v5.3.0...main
