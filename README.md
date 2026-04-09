# Verbatim

Verbatim is a Ruby gem for **declarative version string schemas**. You subclass `Verbatim::Schema`, declare ordered segments in a class-level Domain-Specific Language (DSL), then **parse** strings into structured values and **format** them back with `#to_s`.

Requires **Ruby 3.2+**.

## Installation

Add to your project's Gemfile:

```ruby
gem "verbatim"
```

Install the gem locally:

```bash
bundle install
```

## Use

Define a schema, call `.parse`, use readers or `#[]` / `#to_s`:

```ruby
require "verbatim"

class ApiVersion < Verbatim::Schema
  delimiter "."
  segment :major, :uint
  segment :minor, :uint
end

v = ApiVersion.parse("2.15")
v.major  # => 2
v.minor  # => 15
v[:minor]  # => 15
v.to_s   # => "2.15"
```

Build an instance by hand (useful for tests or construction from other data):

```ruby
ApiVersion.new(major: 1, minor: 0).to_s  # => "1.0"
```

## Semantic Version Schema (Built-in)

`Verbatim::Schemas::SemVer` encodes [Semantic Versioning 2.0.0](https://semver.org/) core version, optional prerelease and build metadata.

```ruby
v = Verbatim::Schemas::SemVer.parse("1.0.0-rc.1+exp.sha.5114f85")
v.major       # => 1
v.minor       # => 0
v.patch       # => 0
v.prerelease  # => "rc.1"
v.build       # => "exp.sha.5114f85"
v.to_s        # => "1.0.0-rc.1+exp.sha.5114f85"
```

## Calendar Version Schema (Built-in)

`Verbatim::Schemas::CalVer` follows a common [Calendar Versioning](https://calver.org/)-style **YYYY.0M.0D** layout with **zero-padding** on `#to_s`.

```ruby
v = Verbatim::Schemas::CalVer.parse("2026.4.8")
v.to_s  # => "2026.04.08"
```

## DSL Reference

#### `delimiter(string)`:
Sets the default string placed **between** consecutive segments when neither segment uses a `lead`.

#### `segment(name, type, **options)`:
Declares one segment, in order. Duplicate names are rejected.


| Option                  | Meaning                                                                                                                                                                                                                                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `optional: true`        | With `lead`: if the input does not start with `lead`, the segment is `nil` and parsing continues. Optional segments without `lead` are not treated specially (use `lead` for optional tails such as SemVer prerelease/build).                                                                                 |
| `lead: "..."`           | Literal prefix **before** this segment’s value (for example `"-"` or `"+"`). Consumed on parse; emitted on `#to_s`. No default delimiter is consumed before a segment that has a `lead`.                                                                                                                      |
| `delimiter_after:`      | `:inherit` (default): after this segment, the next segment (if it has no `lead`) is separated with the schema’s default delimiter. `:none`: do not insert the default delimiter before the next segment (typical before optional `-` / `+` tails). Or pass a string for a fixed delimiter after this segment. |
| Other keyword arguments | Passed through to the segment **type** (for example `leading_zeros: false` on `:uint`, `pattern:` on `:string`, `terminator:` on `:semver_ids`).                                                                                                                                                              |


### Object API

- **Access:** reader per segment (e.g. `#major`), plus `#[](name)` and `#to_h`.
- **`#to_s`:** formats in segment order; omits `nil` optional segments.
- **`#with(**attrs)`:** returns a **new** instance of the same schema with merged segment values.
- **`#succ` / `#pred`:** previous and next along a schema-specific sequence. The base `Verbatim::Schema` raises `NotImplementedError`; override in subclasses or use `#with` to bump fields yourself.
- **Equality:** `#==`, `#eql?`, and `#hash` use the schema class and segment values.
- **`Comparable`:** same-class instances sort together (`nil` optionals before non-`nil` in each slot); different schema classes are incomparable. `Verbatim::Schemas::SemVer` uses SemVer 2.0.0 precedence.
- **`.parse`** returns a frozen instance.

### Class methods

- `YourSchema.parse(string)` → instance
- `YourSchema.format(instance)` → canonical string (same rules as `#to_s`)

## Segment Types


| Type          | Description                                                                                          | Options                                                                                                                                                                                                 |
| ------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `:uint`       | Non-empty ASCII digits → `Integer`; format with `Integer#to_s`, optionally zero-padded via `pad:`    | `leading_zeros: false` disallows multi-digit values with a leading `0`. `pad: N` formats with at least `N` digits (e.g. `pad: 2` → `"08"`). `minimum:` / `maximum:` validate the integer after parsing. |
| `:int`        | Optional leading `-`, then digits → `Integer`; format with `Integer#to_s` (negative values allowed)  | —                                                                                                                                                                                                       |
| `:token`      | Maximal run of `[0-9A-Za-z-]` → string; format the same string                                       | —                                                                                                                                                                                                       |
| `:string`     | Rest of input must match anchored `options[:pattern]`; format `value.to_s`                           | `pattern:` (required Regexp).                                                                                                                                                                           |
| `:semver_ids` | Dot-separated SemVer identifiers until end of string or `terminator`; format joins segments with `.` | `terminator:` (e.g. `"+"` so prerelease stops before build metadata).                                                                                                                                   |


## Custom Segment Types

Register a handler object that responds to `parse(cursor, segment, parse_ctx)` and `format(value, segment)`. Parsing should advance `cursor` and return the Ruby value; formatting returns the string fragment for that segment. Use `Verbatim::Cursor` (`#peek`, `#advance`, `#remainder`, `#starts_with?`, `#eos?`) and `segment.options` for type-specific configuration.

```ruby
Verbatim::Types.register(:my_token, my_handler)

class MySchema < Verbatim::Schema
  delimiter "."
  segment :x, :my_token
end
```

## Errors

Input is interpreted as UTF-8; version strings are expected to be compatible with that (typical ASCII SemVer strings work as intended). Failed parses raise `Verbatim::ParseError` with `#message`, `#string` (full input), `#index` (0-based **character** index into the string), and `#segment` (current segment name as a symbol when applicable, or `nil`).

## License

MIT (see [LICENSE](LICENSE) and [verbatim.gemspec](verbatim.gemspec)).