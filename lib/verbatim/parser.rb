# frozen_string_literal: true

module Verbatim
  # Fills a {Schema} instance by consuming a string according to the schema’s segment list.
  #
  # @api public
  #
  class Parser
    # @param schema_class [Class] subclass of {Schema}
    # @param string [String] input to parse
    # @return [void]
    #
    def initialize(schema_class, string)
      @schema_class = schema_class
      @cursor = Cursor.new(string)
    end

    # Consumes {#initialize}’s string and writes segment values into +instance+.
    #
    # @param instance [Schema] unfrozen or frozen target; receives {#Schema#assign_segment}
    # @return [Schema] +instance+
    # @raise [ParseError] on malformed input or trailing data
    #
    def parse_into(instance)
      segments = @schema_class.segments

      segments.each_with_index do |segment, i|
        if segment.optional? && segment.lead? && !@cursor.starts_with?(segment.lead)
          instance.assign_segment(segment.name, nil)
          next
        end

        if i.positive? && !segment.lead?
          delim = effective_delimiter_after(segments[i - 1])
          expect_delimiter!(delim, segment) if delim && !delim.empty?
        end

        if segment.lead?
          expect_lead!(segment)
          @cursor.advance(segment.lead.length)
        end

        value = Types.parse(segment.type, @cursor, segment, self)
        instance.assign_segment(segment.name, value)
      end

      unless @cursor.eos?
        raise ParseError.new(
          "unexpected trailing data #{@cursor.remainder.inspect}",
          string: @cursor.string,
          index: @cursor.pos,
          segment: nil
        )
      end

      instance
    end

    private

    # Expects a delimiter at the cursor.
    #
    # @param delim [String, nil]
    # @param segment [Segment]
    # @return [void]
    # @raise [ParseError] if +delim+ is present but not at the cursor
    #
    def expect_delimiter!(delim, segment)
      return if delim.nil? || delim.empty?

      unless @cursor.starts_with?(delim)
        raise ParseError.new(
          "expected delimiter #{delim.inspect}",
          string: @cursor.string,
          index: @cursor.pos,
          segment: segment.name
        )
      end
      @cursor.advance(delim.length)
    end

    # Expects a lead at the cursor.
    #
    # @param segment [Segment]
    # @return [void]
    # @raise [ParseError] if the cursor does not start with +segment.lead+
    #
    def expect_lead!(segment)
      return if @cursor.starts_with?(segment.lead)

      raise ParseError.new(
        "expected #{segment.lead.inspect}",
        string: @cursor.string,
        index: @cursor.pos,
        segment: segment.name
      )
    end

    # Returns the effective delimiter after a segment.
    #
    # @param segment [Segment]
    # @return [String, nil] delimiter string to expect after +segment+, or +nil+
    #
    def effective_delimiter_after(segment)
      case segment.delimiter_after
      when :inherit then @schema_class.default_delimiter
      when :none then nil
      else segment.delimiter_after.to_s
      end
    end
  end
end
