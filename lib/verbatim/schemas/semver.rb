# frozen_string_literal: true

require_relative "../errors"
require_relative "../cursor"
require_relative "../segment"
require_relative "../types"
require_relative "../parser"
require_relative "../schema"
require_relative "semver_compare"

module Verbatim
  module Schemas
    # Semantic Versioning 2.0.0 schema (+major.minor.patch+ with optional +-prerelease+ and ++build+).
    #
    # @api public
    #
    class SemVer < Schema
      delimiter "."

      segment :major, :uint, leading_zeros: false
      segment :minor, :uint, leading_zeros: false
      segment :patch, :uint, leading_zeros: false, delimiter_after: :none
      segment :prerelease, :semver_ids,
              optional: true,
              lead: "-",
              terminator: "+"
      segment :build, :semver_ids,
              optional: true,
              lead: "+"

      # Next release along the core line: increments +patch+ and clears prerelease and build.
      #
      # @return [SemVer]
      #
      def succ
        with(patch: patch + 1, prerelease: nil, build: nil)
      end

      # Previous plain release: decrements +patch+, or borrows from +minor+ or +major+ (lower fields zeroed).
      # Only defined when +prerelease+ and +build+ are both absent; raises otherwise.
      #
      # @return [SemVer]
      # @raise [ArgumentError] if prerelease or build is set, or if this is +0.0.0+
      #
      def pred
        if prerelease || build
          raise ArgumentError,
                "SemVer#pred is only defined for plain major.minor.patch (no prerelease or build)"
        end

        if patch.positive?
          with(patch: patch - 1)
        elsif minor.positive?
          with(minor: minor - 1, patch: 0)
        elsif major.positive?
          with(major: major - 1, minor: 0, patch: 0)
        else
          raise ArgumentError, "no predecessor for 0.0.0"
        end
      end

      # SemVer 2.0.0 precedence: core numeric, then prerelease via {SemVerCompare}.
      # Build metadata does not affect precedence; compared last for stable sorting only.
      #
      # @param other [Object]
      # @return [Integer, nil] -1, 0, 1, or +nil+ if +other+ is not a {SemVer}
      def <=>(other)
        return nil unless other.is_a?(SemVer)

        comparison = major <=> other.major
        return comparison if comparison != 0

        comparison = minor <=> other.minor
        return comparison if comparison != 0

        comparison = patch <=> other.patch
        return comparison if comparison != 0

        comparison = SemVerCompare.prerelease(prerelease, other.prerelease)
        return comparison if comparison != 0

        (build || "").to_s <=> (other.build || "").to_s
      end
    end
  end
end
