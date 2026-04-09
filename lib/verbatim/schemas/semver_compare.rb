# frozen_string_literal: true

module Verbatim
  module Schemas
    # SemVer 2.0.0 precedence for prerelease identifiers (+major+/+minor+/+patch+ compared separately in {SemVer#<=>}).
    #
    # @api public
    #
    module SemVerCompare
      module_function

      # Compares prerelease strings per SemVer 2.0.0.
      # +nil+ means a release and sorts *after* any prerelease for the same core.
      #
      # @param left [String, nil]
      # @param right [String, nil]
      # @return [Integer] -1, 0, or 1
      #
      def prerelease(left, right)
        case [left.nil?, right.nil?]
        when [true, true] then 0
        when [true, false] then 1
        when [false, true] then -1
        else
          compare_prerelease_identifiers(left.split(".", -1), right.split(".", -1))
        end
      end

      # Compares prerelease identifiers.
      #
      # @param ids_a [Array<String>]
      # @param ids_b [Array<String>]
      # @return [Integer] -1, 0, or 1
      #
      def compare_prerelease_identifiers(ids_a, ids_b)
        i = 0
        loop do
          a_miss = i >= ids_a.length
          b_miss = i >= ids_b.length
          if a_miss && b_miss
            return 0
          elsif a_miss
            return -1
          elsif b_miss
            return 1
          end

          comparison = compare_identifier(ids_a[i], ids_b[i])
          return comparison if comparison != 0

          i += 1
        end
      end

      # Compares a single prerelease identifier.
      #
      # @param one [String]
      # @param two [String]
      # @return [Integer] -1, 0, or 1
      #
      def compare_identifier(one, two)
        one_num = numeric_identifier?(one)
        two_num = numeric_identifier?(two)
        if one_num && two_num
          Integer(one, 10) <=> Integer(two, 10)
        elsif one_num
          -1
        elsif two_num
          1
        else
          one <=> two
        end
      end

      # Checks if a token is a numeric-only prerelease identifier.
      #
      # @param token [String]
      # @return [Boolean] +true+ if +token+ is numeric-only per SemVer identifier rules
      #
      def numeric_identifier?(token)
        token.match?(/\A[0-9]+\z/) && (token == "0" || token.match?(/\A[1-9]\d*\z/))
      end
    end
  end
end
