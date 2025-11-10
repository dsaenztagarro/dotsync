# frozen_string_literal: true

require_relative "lib/dotsync/version"

Gem::Specification.new do |spec|
  spec.name          = "dotsync"
  spec.version       = Dotsync::VERSION
  spec.authors       = ["David Sáenz"]
  spec.email         = ["david.saenz.tagarro@gmail.com"]

  spec.summary       = "Manage dotfiles like a boss"
  spec.description   = "Keep in sync your dotfiles across machines with a single TOML file"
  spec.homepage      = "https://github.com/dsaenztagarro/dotsync"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dsaenztagarro/dotsync"
  spec.metadata["changelog_uri"] = "https://github.com/dsaenztagarro/dotsync/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "toml-rb", "~> 4.0.0"
  spec.add_dependency "listen", "~> 3.9.0"
  spec.add_dependency "fileutils", "~> 1.7.3"
  spec.add_dependency "logger", "~> 1.7.0" # No longer part of default gems from Ruby 3.5
  spec.add_dependency "ostruct", "~> 0.6.3" # No longer part of default gems from Ruby 3.5
  spec.add_dependency "find", "~> 0.2.0"
  spec.add_dependency "terminal-table", "~> 4.0.0"

  # Debug with:
  # require 'debug'; binding.break
  spec.add_development_dependency "debug", "~> 1.11"
  spec.add_development_dependency "rake", "~> 13.3.0"
  spec.add_development_dependency "rspec", "~> 3.13.1"
  spec.add_development_dependency "rubocop", "~> 1.81.1"
  spec.add_development_dependency "rubocop-rspec", "~> 3.7.0"
  spec.add_development_dependency "rubocop-performance", "~> 1.26.1"
  spec.add_development_dependency "rubocop-rake", "~> 0.7.1"
  spec.add_development_dependency "rubocop-md", "~> 2.0.3"
  spec.add_development_dependency "timecop", "~> 0.9.10"
  spec.add_development_dependency "ruby-lsp", "~> 0.26.1"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "bundler-audit", "~> 0.9.0"
end
