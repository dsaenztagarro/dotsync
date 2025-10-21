
require_relative "lib/dotsync/version"

Gem::Specification.new do |spec|
  spec.name          = "dotsync"
  spec.version       = Dotsync::VERSION
  spec.authors       = ["David Sáenz"]
  spec.email         = ["david.saenz.tagarro@gmail.com"]

  spec.summary       = "DotSync Automator"
  spec.description   = "DotSync Automator"
  spec.homepage      = "https://github.com/dsaenztagarro/dotsync"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dsaenztagarro/dotsync"
  spec.metadata["changelog_uri"] = "https://github.com/dsaenztagarro/dotsync/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "toml-rb"
  spec.add_dependency "listen"
  spec.add_dependency "fileutils"
  spec.add_dependency "logger" # No longer part of default gems from Ruby 3.5
  spec.add_dependency "ostruct" # No longer part of default gems from Ruby 3.5
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "ruby-lsp"
end
