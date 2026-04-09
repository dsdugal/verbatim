# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- (nothing yet)

## [0.1.0] - 2026-04-08

### Added

- `Verbatim::Schema` DSL: `delimiter`, `segment` with `optional`, `lead`, `delimiter_after`, and type-specific options.
- Built-in segment types: `:uint`, `:int`, `:token`, `:string`, `:semver_ids`.
- `Verbatim::Schemas::SemVer` and `Verbatim::Schemas::CalVer`.
- `.parse` / `.format`, value API: readers, `#[]`, `#to_h`, `#to_s`, equality, `Comparable` (SemVer uses 2.0.0 precedence).
- `Verbatim::ParseError` with message, string, index, and segment.
- Instance `#with(**attrs)`; `#succ` / `#pred` on `Schema` (default `NotImplementedError`), with CalVer (calendar day) and SemVer (patch bump / core predecessor) implementations.
- MIT `LICENSE` included in the gem.

[Unreleased]: https://github.com/dsdugal/verbatim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dsdugal/verbatim/releases/tag/v0.1.0
