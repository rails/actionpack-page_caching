# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = 'actionpack-page_caching_multithread'
  gem.version       = '1.2'
  gem.author        = 'Dimelo'
  gem.email         = 'contact@dimelo.com'
  gem.description   = 'Threadsafe Static page caching for Action Pack 4.x'
  gem.summary       = 'Threadsafe Static page caching for Action Pack 4.x'
  gem.homepage      = 'https://github.com/dimelo/actionpack-page_caching_multithread'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'actionpack', '>= 4.0.0', '< 5'

  gem.add_development_dependency 'mocha'
end
