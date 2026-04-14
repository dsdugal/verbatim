# frozen_string_literal: true

module Verbatim
  # Character-position cursor over a UTF-8 string; used by the parser and custom type handlers.
  #
  # @api public
  #
  class Cursor
    # @return [String] the full string being scanned (UTF-8)
    attr_reader :string
    # @return [Integer] current zero-based character index into {#string}
    attr_reader :pos

    # @param string [String] input; re-encoded to UTF-8
    # @return [void]
    #
    def initialize(string)
      @string = string.encode(Encoding::UTF_8)
      @pos = 0
    end

    # Checks if the cursor is at the end of the string.
    #
    # @return [Boolean] +true+ if no characters remain after {#pos}
    #
    def eos?
      pos >= string.length
    end

    # Returns the remainder of the string from the current position to the end.
    #
    # @return [String] substring from {#pos} through end of {#string}
    #
    def remainder
      string[pos..] || ""
    end

    # Returns up to +count+ characters at {#pos}, or empty string at end.
    #
    # @param count [Integer] number of characters to peek (default 1)
    # @return [String] up to +count+ characters at {#pos}, or empty string at end
    #
    def peek(count = 1)
      string[pos, count] || ""
    end

    # Advances the cursor by +delta+ characters.
    #
    # @param delta [Integer] number of character positions to advance (default 1)
    # @return [void]
    #
    def advance(delta = 1)
      @pos += delta
    end

    # Checks if the cursor starts with a given prefix.
    #
    # @param prefix [String] literal prefix to test
    # @return [Boolean] +true+ if {#string} at {#pos} starts with +prefix+
    #
    def starts_with?(prefix)
      string[pos, prefix.length] == prefix
    end
  end
end
