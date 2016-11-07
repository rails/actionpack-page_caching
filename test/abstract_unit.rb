require "bundler/setup"
require "minitest/autorun"
require "action_controller"
require "action_controller/page_caching"
require "rails/version"

if ActiveSupport.respond_to?(:test_order)
  ActiveSupport.test_order = :random
end

if ActionController::Base.respond_to?(:enable_fragment_cache_logging=)
  ActionController::Base.enable_fragment_cache_logging = true
end

if Rails::VERSION::STRING < "4.1"
  ActionController::Renderers.add :html do |text, options|
    self.content_type = Mime[:html]
    text
  end
end
