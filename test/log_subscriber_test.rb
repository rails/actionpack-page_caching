require 'abstract_unit'
require 'active_support/log_subscriber/test_helper'
require 'action_controller/log_subscriber'

module Another
  class LogSubscribersController < ActionController::Base
    abstract!

    self.perform_caching = true

    def with_page_cache
      cache_page('Super soaker', '/index.html')
      render nothing: true
    end
  end
end

class ACLogSubscriberTest < ActionController::TestCase
  tests Another::LogSubscribersController
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super

    @routes = SharedTestRoutes
    @routes.draw do
      get ':controller(/:action)'
    end

    @cache_path = File.expand_path('../temp/test_cache', File.dirname(__FILE__))
    ActionController::Base.page_cache_directory = @cache_path
    @controller.cache_store = :file_store, @cache_path
    ActionController::LogSubscriber.attach_to :action_controller
  end

  def teardown
    ActiveSupport::LogSubscriber.log_subscribers.clear
    FileUtils.rm_rf(@cache_path)
  end

  def set_logger(logger)
    ActionController::Base.logger = logger
  end

  def test_with_page_cache
    get :with_page_cache
    wait

    logs = @logger.logged(:info)
    assert_equal 3, logs.size
    assert_match(/Write page/, logs[1])
    assert_match(/\/index\.html/, logs[1])
  end
end
