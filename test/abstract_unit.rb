require "bundler/setup"
require "minitest/autorun"
require "action_controller"
require "action_controller/page_caching"

if ActiveSupport.respond_to?(:test_order)
  ActiveSupport.test_order = :random
end

if ActionController::Base.respond_to?(:enable_fragment_cache_logging=)
  ActionController::Base.enable_fragment_cache_logging = true
end
