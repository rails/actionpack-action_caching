# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = 'actionpack-action_caching'
  gem.version       = '0.0.1'
  gem.authors       = 'David Heinemeier Hansson'
  gem.email         = 'david@loudthinking.com'
  gem.description   = 'Action caching'
  gem.summary       = 'Action caching'
  gem.homepage      = 'https://github.com/rails/actionpack-action_caching'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'actionpack', '>= 4.0.0.beta', '< 5.0'

  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'activerecord', '>= 4.0.0.beta', '< 5.0'
end
