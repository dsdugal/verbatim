# frozen_string_literal: true

module Verbatim
  # Raised when a string does not match the expected schema layout.
  #
  # @api public
  #
  class ParseError < StandardError
    # @return [String] the full input string that was being parsed
    attr_reader :string
    # @return [Integer] zero-based character index of the error position in {#string}
    attr_reader :index
    # @return [Symbol, nil] segment name when known, or +nil+
    attr_reader :segment

    # @param message [String] human-readable error description
    # @param string [String] full input string
    # @param index [Integer] character index where parsing failed
    # @param segment [Symbol, nil] segment name when applicable
    # @return [void]
    #
    def initialize(message, string:, index:, segment: nil)
      super(message)
      @string = string
      @index = index
      @segment = segment
    end
  end
end
