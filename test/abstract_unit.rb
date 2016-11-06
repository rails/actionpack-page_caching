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
        get 'page_caching_metal_test/ok' => 'page_caching_metal_test#ok'
        scope controller: :page_caching_test, path: 'page_caching_test' do
          get :about_me
          get :custom_path
          get :default_gzip
          get :expire_custom_path
          get :found
          get :gzip_level
          get :no_content
          get :no_gzip
          get :not_found
          get :ok
        end
      end
    end
  end
end
