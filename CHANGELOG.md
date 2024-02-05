# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.2.0] - 2024-02-05

### Added

- Add `Connection#finished_request?`
  ([#743](https://github.com/httprb/http/pull/743))
- Add `Instrumentation#on_error`
  ([#746](https://github.com/httprb/http/pull/746))
- Add `base64` dependency (suppresses warnings on Ruby 3.0)
  ([#759](https://github.com/httprb/http/pull/759))
- Add `PURGE` HTTP verb
  ([#757](https://github.com/httprb/http/pull/757))
- Add Ruby-3.3 support

### Changed

- **BREAKING** Process features in reverse order
  ([#766](https://github.com/httprb/http/pull/766))
- **BREAKING** Downcase Content-Type charset name
  ([#753](https://github.com/httprb/http/pull/753))
- **BREAKING** Make URI normalization more conservative
  ([#758](https://github.com/httprb/http/pull/758))

### Fixed

- Close sockets on initialize failure
  ([#762](https://github.com/httprb/http/pull/762))
- Prevent CRLF injection due to broken URL normalizer
  ([#765](https://github.com/httprb/http/pull/765))

[unreleased]: https://github.com/httprb/http/compare/v5.2.0...5-x-stable
[5.2.0]: https://github.com/httprb/http/compare/v5.1.1...v5.2.0
