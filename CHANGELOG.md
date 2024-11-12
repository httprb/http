# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [6.0.0] - 2024-08-28

### Added

- Add `HTTP.retriable` API (#775)
- Add more granularity to `HTTP::ConnectionError` (#783)
- Cache header normalization to reduce object allocation (#789)

### Changed

- **BREAKING** Handle responses in the reverse order from the requests (#776)
- Drop `base64` gem dependency (#778)

### Removed

- **BREAKING** Drop Ruby 2.x support

[unreleased]: https://github.com/httprb/http/compare/v5.2.0...main
[6.0.0]: https://github.com/httprb/http/compare/v5.2.0...v6.0.0
