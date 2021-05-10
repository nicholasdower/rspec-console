# frozen_string_literal: true

require_relative "lib/rspec-interactive/version"

Gem::Specification.new do |spec|
  spec.name          = "rspec-interactive"
  spec.version       = RSpecInteractive::VERSION
  spec.authors       = ["Nick Dower"]
  spec.email         = ["nicholasdower@gmail.com"]

  spec.summary       = "An interactive console for running specs."
  spec.description   = "An interactive console for running specs."
  spec.homepage      = "https://github.com/nicholasdower/rspec-interactive"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/nicholasdower/rspec-interactive"
  spec.metadata["changelog_uri"] = "https://github.com/nicholasdower/rspec-interactive"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  spec.executables   << 'rspec-interactive'
  spec.require_paths = ["lib"]

  spec.add_dependency "listen"
end
