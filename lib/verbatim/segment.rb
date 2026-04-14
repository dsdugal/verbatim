# frozen_string_literal: true

module Verbatim
  # Immutable description of one field in a {Schema} (name, type, delimiters, options).
  #
  # @api public
  #
  class Segment
    # @return [Symbol] segment field name
    attr_reader :name
    # @return [Symbol] registered type key (e.g. +:uint+)
    attr_reader :type
    # @return [Boolean] whether the segment may be omitted when its +lead+ is absent
    attr_reader :optional
    # @return [String, nil] literal prefix before the value (e.g. +-+), or +nil+
    attr_reader :lead
    # @return [Symbol, String] +:inherit+, +:none+, or an explicit delimiter string after this segment
    attr_reader :delimiter_after
    # @return [Hash] type-specific options (frozen)
    attr_reader :options

    # @param name [Symbol]
    # @param type [Symbol]
    # @param optional [Boolean]
    # @param lead [String, nil]
    # @param delimiter_after [Symbol, String] +:inherit+ (default), +:none+, or delimiter string
    # @param options [Hash] extra options passed to the type handler
    # @return [void]
    #
    def initialize(name:, type:, optional: false, lead: nil, delimiter_after: :inherit, options: {})
      @name = name
      @type = type
      @optional = optional
      @lead = lead
      @delimiter_after = delimiter_after
      @options = options.freeze
      freeze
    end

    # Checks if the segment is optional.
    #
    # @return [Boolean] +true+ if {#optional} is +true+
    #
    def optional?
      optional
    end

    # Checks if the segment has a lead.
    #
    # @return [Boolean] +true+ if {#lead} is non-empty
    #
    def lead?
      !lead.nil? && !lead.empty?
    end
  end
end
