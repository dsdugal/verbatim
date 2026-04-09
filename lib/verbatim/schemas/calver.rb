# frozen_string_literal: true

require "date"

require_relative "../errors"
require_relative "../cursor"
require_relative "../segment"
require_relative "../types"
require_relative "../parser"
require_relative "../schema"

module Verbatim
  module Schemas
    # Calendar-style +YYYY.0M.0D+ version (+year+, zero-padded +month+ and +day+ in {#to_s}).
    #
    # Parsing accepts unpadded or padded numeric components (e.g. +2026.4.8+ or +2026.04.08+).
    # This does not enforce real calendar dates (+2026.02.31+ parses); add your own validation if needed.
    #
    # @api public
    #
    class CalVer < Schema
      delimiter "."

      segment :year, :uint, pad: 4
      segment :month, :uint, pad: 2, minimum: 1, maximum: 12
      segment :day, :uint, pad: 2, minimum: 1, maximum: 31

      # Next calendar day.
      #
      # @return [CalVer]
      # @raise [ArgumentError] if the current date is invalid for +Date+ (e.g. Feb 30)
      #
      def succ
        step_calendar(1)
      end

      # Previous calendar day.
      #
      # @return [CalVer]
      # @raise [ArgumentError] if the current date is invalid for +Date+ (e.g. Feb 30)
      #
      def pred
        step_calendar(-1)
      end

      private

      # @param delta [Integer] days to add (+1 / +-1+)
      # @return [CalVer]
      #
      def step_calendar(delta)
        d = Date.new(year, month, day) + delta
        with(year: d.year, month: d.month, day: d.day)
      rescue ArgumentError, Date::Error => e
        raise ArgumentError, "invalid calendar date for CalVer#succ/#pred: #{e.message}"
      end
    end
  end
end
