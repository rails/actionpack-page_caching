require 'bundler/setup'
require 'minitest/autorun'
require 'action_controller'
require 'action_controller/page_caching'

SharedTestRoutes = ActionDispatch::Routing::RouteSet.new

module ActionController
  class Base
    include SharedTestRoutes.url_helpers
  end

  class TestCase
    def setup
      @routes = SharedTestRoutes

      @routes.draw do
        get ':controller(/:action)'
      end
    end
  end
end
