Gem::Specification.new do |gem|
  gem.name          = "actionpack-action_caching"
  gem.version       = "1.2.2"
  gem.author        = "David Heinemeier Hansson"
  gem.email         = "david@loudthinking.com"
  gem.description   = "Action caching for Action Pack (removed from core in Rails 4.0)"
  gem.summary       = "Action caching for Action Pack (removed from core in Rails 4.0)"
  gem.homepage      = "https://github.com/rails/actionpack-action_caching"

  gem.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/actionpack-action_caching/issues",
    "changelog_uri"     => "https://github.com/rails/actionpack-action_caching/blob/v#{gem.version}/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/actionpack-action_caching/#{gem.version}",
    "source_code_uri"   => "https://github.com/rails/actionpack-action_caching/tree/v#{gem.version}",
  }

  gem.required_ruby_version = ">= 1.9.3"
  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.license       = "MIT"

  gem.add_dependency "actionpack", ">= 4.0.0"

  gem.add_development_dependency "mocha"
  gem.add_development_dependency "activerecord", ">= 4.0.0"
end
