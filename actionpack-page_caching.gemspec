Gem::Specification.new do |gem|
  gem.name          = "actionpack-page_caching"
  gem.version       = "1.2.3"
  gem.author        = "David Heinemeier Hansson"
  gem.email         = "david@loudthinking.com"
  gem.description   = "Static page caching for Action Pack (removed from core in Rails 4.0)"
  gem.summary       = "Static page caching for Action Pack (removed from core in Rails 4.0)"
  gem.homepage      = "https://github.com/rails/actionpack-page_caching"
  gem.license       = "MIT"

  gem.required_ruby_version = ">= 2.4.6"
  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.license       = "MIT"

  gem.add_dependency "actionpack", ">= 5.0.0"

  gem.add_development_dependency 'brotli', '>= 0.2.0'
  gem.add_development_dependency "mocha"

  gem.post_install_message = "To use brotli compression you have to manually add gem 'brotli' to Gemfile"
end
