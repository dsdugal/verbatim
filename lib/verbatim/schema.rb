# frozen_string_literal: true

module Verbatim
  # Base class for declarative version (or token) schemas. Subclasses declare {#segment}s and use {.parse}.
  # Each {.segment} defines a public instance reader with the same name as the segment.
  #
  # @api public
  #
  class Schema
    include Comparable

    class << self
      # Subclasses must call +super+ and initialize {#segments}, {#default_delimiter}, and {#segment_names}.
      #
      # @param subclass [Class]
      # @return [void]
      #
      def inherited(subclass)
        super

        subclass.instance_variable_set(:@segments, [])
        subclass.instance_variable_set(:@default_delimiter, ".")
        subclass.instance_variable_set(:@segment_names, [])
      end

      # @return [Array<Segment>] segments in declaration order
      #
      def segments
        @segments ||= []
      end

      # Sets or returns the default delimiter between segments (when the next segment has no +lead+).
      #
      # @param value [String, nil] if +nil+, returns the current default without changing it
      # @return [String] the active default delimiter
      #
      def delimiter(value = nil)
        @default_delimiter ||= "."
        return @default_delimiter if value.nil?

        @default_delimiter = value.to_s
      end

      alias default_delimiter delimiter

      # Declares a segment and defines an instance reader for +name+.
      #
      # @param name [Symbol]
      # @param type [Symbol] registered in {Types.register}
      # @param optional [Boolean]
      # @param lead [String, nil]
      # @param delimiter_after [Symbol, String] +:inherit+, +:none+, or explicit string
      # @param options [Hash] forwarded to the type handler (e.g. +pad:+, +pattern:+)
      # @return [void]
      # @raise [ArgumentError] on duplicate segment +name+
      #
      def segment(name, type, optional: false, lead: nil, delimiter_after: :inherit, **options)
        name = name.to_sym
        @segment_names ||= []
        @segments ||= []
        @default_delimiter ||= "."

        raise ArgumentError, "duplicate segment #{name.inspect}" if @segment_names.include?(name)

        @segment_names << name

        segments << Segment.new(
          name: name,
          type: type.to_sym,
          optional: optional,
          lead: lead&.to_s,
          delimiter_after: delimiter_after,
          options: options
        )

        define_reader(name)
      end

      # Parses a string into a new instance of the schema class.
      #
      # @param string [String]
      # @return [Schema] a frozen instance populated from +string+
      # @raise [ParseError] on invalid input
      #
      def parse(string)
        allocate.tap do |instance|
          instance.send(:initialize_values)
          Parser.new(self, string).parse_into(instance)
          instance.freeze
        end
      end

      # Formats an instance of the schema class into a canonical string.
      #
      # @param instance [Schema] same class as this schema
      # @return [String] canonical string for +instance+
      # @raise [ArgumentError] if a required segment value is missing
      #
      def format(instance)
        parts = []

        segments.each_with_index do |segment, index|
          value = instance.send(segment.name)
          next if value.nil? && segment.optional?

          raise ArgumentError, "missing required segment #{segment.name}" if value.nil?

          if index.zero?
            parts << Types.format(segment.type, value, segment)
          elsif segment.lead?
            parts << segment.lead.to_s << Types.format(segment.type, value, segment)
          else
            delim = delimiter_before_format(segments, index)
            parts << delim if delim && !delim.empty?
            parts << Types.format(segment.type, value, segment)
          end
        end

        parts.join
      end

      private

      # Defines a public instance reader for +name+.
      #
      # @param name [Symbol]
      # @return [void]
      #
      def define_reader(name)
        define_method(name) { @values[name] }
      end

      # Returns the delimiter before the given segment when formatting.
      #
      # @param segments [Array<Segment>]
      # @param index [Integer] index of the segment being formatted
      # @return [String, nil] delimiter before that segment when formatting
      #
      def delimiter_before_format(segments, index)
        return if index.zero?

        prev = segments[index - 1]

        case prev.delimiter_after
        when :inherit then delimiter(nil)
        when :none then nil
        else prev.delimiter_after.to_s
        end
      end
    end

    # @param values [Hash] segment name => parsed value
    # @return [void]
    #
    def initialize(**values)
      initialize_values

      values.each { |name, value| assign_segment(name.to_sym, value) }
    end

    # Assigns a value to a segment.
    #
    # @param name [Symbol, String]
    # @param value [Object]
    # @return [void]
    # @raise [FrozenError] if +self+ is frozen
    #
    def assign_segment(name, value)
      @values[name.to_sym] = value
    end

    # Returns the value of a segment.
    #
    # @param name [Symbol, String]
    # @return [Object] segment value, or +nil+ if unset
    #
    def [](name)
      @values[name.to_sym]
    end

    # Returns a copy of the internal segment values.
    #
    # @return [Hash{Symbol => Object}] copy of internal segment values
    #
    def to_h
      @values.dup
    end

    # Returns a new instance of the same schema with segment values merged over +self+.
    #
    # @param overrides [Hash] segment names (symbols or strings) => new values
    # @return [Schema] unfrozen instance; does not mutate +self+
    #
    def with(**overrides)
      base = self.class.segments.each_with_object({}) { |s, h| h[s.name] = @values[s.name] }
      self.class.new(**base.merge(overrides.transform_keys(&:to_sym)))
    end

    # Next sequential value for this schema. The base implementation raises; subclasses
    # may override (e.g. {Schemas::CalVer}, {Schemas::SemVer}).
    #
    # @return [Schema]
    # @raise [NotImplementedError] unless overridden
    #
    def succ
      raise NotImplementedError, "#{self.class} does not define #succ; override it or use #with"
    end

    # Previous sequential value for this schema. The base implementation raises; subclasses
    # may override (e.g. {Schemas::CalVer}, {Schemas::SemVer}).
    #
    # @return [Schema]
    # @raise [NotImplementedError] unless overridden
    #
    def pred
      raise NotImplementedError, "#{self.class} does not define #pred; override it or use #with"
    end

    # Returns the canonical string representation of the instance.
    #
    # @return [String] {.format}(+self+)
    #
    def to_s
      self.class.format(self)
    end

    # Returns a string representation of the instance.
    #
    # @return [String]
    #
    def inspect
      attrs = self.class.segments.map { |segment| "#{segment.name}=#{@values[segment.name].inspect}" }.join(", ")

      "#<#{self.class.name} #{attrs}>"
    end

    # Compares two instances of the same class.
    #
    # @param other [Object]
    # @return [Boolean]
    #
    def ==(other)
      other.is_a?(self.class) && @values == other.instance_variable_get(:@values)
    end

    alias eql? ==

    # Returns a hash code for the instance.
    #
    # @return [Integer] hash consistent with {#eql?}
    #
    def hash
      [self.class, @values].hash
    end

    # Compares two instances of the same class in segment declaration order;
    # +nil+ optional values sort before non-+nil+. Subclasses (e.g. {Schemas::SemVer}) may override.
    #
    # @param other [Object]
    # @return [Integer, nil] -1, 0, 1, or +nil+ if not comparable (different class or incomparable values)
    #
    def <=>(other)
      return nil unless other.is_a?(self.class)

      segs = self.class.segments
      i = 0
      while i < segs.length
        segment = segs[i]
        comparison = compare_values_for_sort(@values[segment.name], other.send(segment.name))
        return nil if comparison.nil?

        return comparison if comparison != 0

        i += 1
      end

      0
    end

    private

    # Compares two values for sort order.
    #
    # @param left [Object, nil]
    # @param right [Object, nil]
    # @return [Integer, nil]
    #
    def compare_values_for_sort(left, right)
      if left.nil? && right.nil?
        0
      elsif left.nil?
        -1
      elsif right.nil?
        1
      else
        comparison = left <=> right

        return if comparison.nil?

        comparison
      end
    end

    # Initializes the internal segment values.
    #
    # @return [void]
    #
    def initialize_values
      @values = {}
    end
  end
end
