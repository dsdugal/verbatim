# frozen_string_literal: true

module Verbatim
  # Registry and dispatch for segment type handlers (+:uint+, +:int+, custom types).
  #
  # @api public
  #
  module Types
    class << self
      # Parses a value from a string according to a segment type.
      #
      # @param type [Symbol]
      # @param cursor [Cursor]
      # @param segment [Segment]
      # @param parse_ctx [Object] opaque context (currently {Parser}); reserved for handlers
      # @return [Object] parsed value
      # @raise [ArgumentError] if +type+ is unknown
      # @raise [ParseError] if the handler rejects input
      #
      def parse(type, cursor, segment, parse_ctx)
        handler = registry.fetch(type) { raise ArgumentError, "unknown segment type: #{type.inspect}" }
        handler.parse(cursor, segment, parse_ctx)
      end

      # Formats a value into a string according to a segment type.
      #
      # @param type [Symbol]
      # @param value [Object]
      # @param segment [Segment]
      # @return [String] fragment for {#Schema#to_s}
      # @raise [ArgumentError] if +type+ is unknown or +value+ is invalid for the type
      #
      def format(type, value, segment)
        handler = registry.fetch(type) { raise ArgumentError, "unknown segment type: #{type.inspect}" }
        handler.format(value, segment)
      end

      # Registers a new type handler.

      # @param type [Symbol]
      # @param handler [Object] object responding to +parse(cursor, segment, parse_ctx)+ and +format(value, segment)+
      # @return [void]
      #
      def register(type, handler)
        registry[type] = handler
      end

      private

      # Returns the registry of type handlers.
      #
      # @return [Hash{Symbol => Object}] registry of type handlers
      #
      def registry
        @registry ||= {}
      end
    end

    # Internal helpers and built-in type handler implementations.

    module Handlers
      module_function

      # Raises a parse error.

      # @param cursor [Cursor]
      # @param segment [Segment, nil]
      # @param message [String]
      # @return [void]
      # @raise [ParseError]

      def fail_parse!(cursor, segment, message)
        raise ParseError.new(
          message,
          string: cursor.string,
          index: cursor.pos,
          segment: segment&.name
        )
      end

      # Unsigned decimal integer segment type (+:uint+).
      #
      # @api public
      #
      class Uint
        # Parses a value from a string according to a segment type.
        #
        # @param cursor [Cursor]
        # @param segment [Segment]
        # @param _parse_ctx [Object]
        # @return [Integer]
        # @raise [ParseError]
        #
        def parse(cursor, segment, _parse_ctx)
          start = cursor.pos
          Handlers.fail_parse!(cursor, segment, "expected digit") if cursor.eos? || cursor.peek !~ /\d/

          cursor.advance(1) while !cursor.eos? && cursor.peek =~ /\d/
          raw = cursor.string[start, cursor.pos - start]
          if segment.options[:leading_zeros] == false && raw.length > 1 && raw.start_with?("0")
            Handlers.fail_parse!(cursor, segment, "leading zeros not allowed")
          end
          value = Integer(raw, 10)
          validate_uint_range!(cursor, segment, value)

          value
        end

        # Formats a value into a string according to a segment type.
        #
        # @param value [Integer]
        # @param segment [Segment]
        # @return [String]
        # @raise [ArgumentError]
        #
        def format(value, segment)
          raise ArgumentError, "uint value must be Integer, got #{value.class}" unless value.is_a?(Integer)

          pad = segment.options[:pad]
          if pad
            raise ArgumentError, "options[:pad] must be a positive Integer" unless pad.is_a?(Integer) && pad.positive?

            Kernel.format("%0*d", pad, value)
          else
            value.to_s
          end
        end

        private

        # Validates the range of a uint value.
        #
        # @param cursor [Cursor]
        # @param segment [Segment]
        # @param value [Integer]
        # @return [void]
        # @raise [ParseError]
        #
        def validate_uint_range!(cursor, segment, value)
          if (min = segment.options[:minimum]) && value < min
            Handlers.fail_parse!(cursor, segment, "value #{value} is below minimum #{min}")
          end
          return unless (max = segment.options[:maximum]) && value > max

          Handlers.fail_parse!(cursor, segment, "value #{value} is above maximum #{max}")
        end
      end

      # Signed decimal integer (+optional leading +-+); +:int+ type.
      #
      # @api public
      #
      class Int
        # Parses a value from a string according to a segment type.
        #
        # @param cursor [Cursor]
        # @param segment [Segment]
        # @param _parse_ctx [Object]
        # @return [Integer]
        # @raise [ParseError]
        #
        def parse(cursor, segment, _parse_ctx)
          start = cursor.pos
          cursor.advance(1) if !cursor.eos? && cursor.peek == "-"
          Handlers.fail_parse!(cursor, segment, "expected digit") if cursor.eos? || cursor.peek !~ /\d/

          cursor.advance(1) while !cursor.eos? && cursor.peek =~ /\d/
          raw = cursor.string[start, cursor.pos - start]
          Integer(raw, 10)
        end

        # Formats a value into a string according to a segment type.
        #
        # @param value [Integer]
        # @param _segment [Segment]
        # @return [String]
        # @raise [ArgumentError]
        #
        def format(value, _segment)
          raise ArgumentError, "int value must be Integer, got #{value.class}" unless value.is_a?(Integer)

          value.to_s
        end
      end

      # Non-empty run of +[0-9A-Za-z-]+; +:token+ type.
      #
      # @api public
      #
      class Token
        # Parses a value from a string according to a segment type.
        #
        # @param cursor [Cursor]
        # @param segment [Segment]
        # @param _parse_ctx [Object]
        # @return [String]
        # @raise [ParseError]
        #
        def parse(cursor, segment, _parse_ctx)
          start = cursor.pos
          if cursor.eos? || cursor.peek !~ /[0-9A-Za-z-]/
            Handlers.fail_parse!(cursor, segment,
                                 "expected token character")
          end

          cursor.advance(1) while !cursor.eos? && cursor.peek =~ /[0-9A-Za-z-]/
          cursor.string[start, cursor.pos - start]
        end

        # Formats a value into a string according to a segment type.
        #
        # @param value [Object] coerced with +#to_s+
        # @param _segment [Segment]
        # @return [String]
        # @raise [ArgumentError] if the string is empty
        #
        def format(value, _segment)
          string = value.to_s

          raise ArgumentError, "token must be non-empty" if string.empty?

          string
        end
      end

      # Match anchored regexp; +:string+ type (+options[:pattern]+ required).
      #
      # @api public
      #
      class StringType
        # Parses a value from a string according to a segment type.
        #
        # @param cursor [Cursor]
        # @param segment [Segment]
        # @param _parse_ctx [Object]
        # @return [String]
        # @raise [ArgumentError] if +pattern+ is missing
        # @raise [ParseError] if the remainder does not match
        #
        def parse(cursor, segment, _parse_ctx)
          pattern = segment.options[:pattern]
          raise ArgumentError, ":string requires options[:pattern] Regexp" unless pattern.is_a?(Regexp)

          rest = cursor.remainder
          anchored = Regexp.new("\\A(?:#{pattern.source})", pattern.options)
          m = anchored.match(rest)
          Handlers.fail_parse!(cursor, segment, "did not match pattern") unless m

          cursor.advance(m.end(0))
          m[0]
        end

        # Formats a value into a string according to a segment type.
        #
        # @param value [Object]
        # @param _segment [Segment]
        # @return [String]
        #
        def format(value, _segment)
          value.to_s
        end
      end

      # Dot-separated SemVer identifier string; +:semver_ids+ type.
      #
      # @api public
      #
      class SemverIdentifiers
        # Checks if a token is a valid SemVer 2.0 identifier.
        #
        # @param token [String]
        # @return [Boolean] +true+ if +token+ is a valid SemVer 2.0 identifier
        #
        def self.valid_ident?(token)
          return false if token.empty?

          if token.match?(/\A[0-9]+\z/)
            token == "0" || token.match?(/\A[1-9]\d*\z/)
          else
            token.match?(/\A[0-9A-Za-z-]+\z/)
          end
        end

        # Parses a value from a string according to a segment type.
        #
        # @param cursor [Cursor]
        # @param segment [Segment]
        # @param _parse_ctx [Object]
        # @return [String] dot-separated identifiers (no leading +lead+)
        # @raise [ParseError]
        #
        def parse(cursor, segment, _parse_ctx)
          terminator = segment.options[:terminator]
          rest = cursor.remainder
          stop_idx = if terminator
                       idx = rest.index(terminator)
                       idx.nil? ? rest.length : idx
                     else
                       rest.length
                     end
          chunk = rest[0, stop_idx]
          Handlers.fail_parse!(cursor, segment, "expected semver identifiers") if chunk.empty?

          chunk.split(".", -1).each do |p|
            unless self.class.valid_ident?(p)
              Handlers.fail_parse!(cursor, segment,
                                   "invalid semver identifier #{p.inspect}")
            end
          end
          cursor.advance(chunk.length)

          chunk
        end

        # Formats a value into a string according to a segment type.
        #
        # @param value [Object]
        # @param _segment [Segment]
        # @return [String]
        # @raise [ArgumentError] if empty or any identifier is invalid
        #
        def format(value, _segment)
          string = value.to_s
          raise ArgumentError, "semver identifiers must be non-empty" if string.empty?

          string.split(".", -1).each do |p|
            raise ArgumentError, "invalid semver identifier #{p.inspect}" unless self.class.valid_ident?(p)
          end

          string
        end
      end
    end
  end
end

Verbatim::Types.register(:uint, Verbatim::Types::Handlers::Uint.new)
Verbatim::Types.register(:int, Verbatim::Types::Handlers::Int.new)
Verbatim::Types.register(:token, Verbatim::Types::Handlers::Token.new)
Verbatim::Types.register(:string, Verbatim::Types::Handlers::StringType.new)
Verbatim::Types.register(:semver_ids, Verbatim::Types::Handlers::SemverIdentifiers.new)
