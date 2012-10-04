# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'actionpack-action_caching/version'

Gem::Specification.new do |gem|
  gem.name          = 'actionpack-action_caching'
  gem.version       = ActionPack::ActionCaching::VERSION
  gem.authors       = 'David Heinemeier Hansson'
  gem.email         = 'david@loudthinking.com'
  gem.description   = 'Action caching'
  gem.summary       = 'Action caching'
  gem.homepage      = 'https://github.com/rails/actionpack-action_caching'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
end
