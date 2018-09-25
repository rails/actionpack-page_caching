Gem::Specification.new do |gem|
  gem.name          = "actionpack-page_caching"
  gem.version       = "1.1.1"
  gem.author        = "David Heinemeier Hansson"
  gem.email         = "david@loudthinking.com"
  gem.description   = "Static page caching for Action Pack (removed from core in Rails 4.0)"
  gem.summary       = "Static page caching for Action Pack (removed from core in Rails 4.0)"
  gem.homepage      = "https://github.com/rails/actionpack-page_caching"
  gem.license       = "MIT"

  gem.required_ruby_version = '>= 1.9.3'
  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.license       = 'MIT'

  gem.add_dependency "actionpack", ">= 4.0.0", "< 6"

  gem.add_development_dependency "mocha"
end
