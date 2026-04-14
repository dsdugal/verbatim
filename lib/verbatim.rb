# frozen_string_literal: true

require_relative "verbatim/version"
require_relative "verbatim/errors"
require_relative "verbatim/cursor"
require_relative "verbatim/segment"
require_relative "verbatim/types"
require_relative "verbatim/parser"
require_relative "verbatim/schema"
require_relative "verbatim/schemas/semver"
require_relative "verbatim/schemas/calver"

# Root namespace for the Verbatim version-schema library.
#
# @api public
#
module Verbatim
end
