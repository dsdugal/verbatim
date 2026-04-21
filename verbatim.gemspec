# frozen_string_literal: true

require_relative "lib/verbatim/version"

Gem::Specification.new do |spec|
  spec.name = "verbatim"
  spec.version = Verbatim::VERSION
  spec.authors = ["Dustin Dugal"]
  spec.summary = "Declarative software version schemas"
  spec.homepage = "https://github.com/dsdugal/verbatim"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/dsdugal/verbatim/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*"].select { File.file?(_1) } + %w[CHANGELOG.md LICENSE README.md]
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"

  spec.metadata["rubygems_mfa_required"] = "true"
end
