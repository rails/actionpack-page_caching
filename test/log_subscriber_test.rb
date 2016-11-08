require "abstract_unit"
require "active_support/log_subscriber/test_helper"
require "action_controller/log_subscriber"

module Another
  class LogSubscribersController < ActionController::Base
    abstract!

    self.perform_caching = true

    def with_page_cache
      cache_page("Super soaker", "/index.html")
      head :ok
    end
  end
end

class ACLogSubscriberTest < ActionController::TestCase
  tests Another::LogSubscribersController
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super

    @routes = ActionDispatch::Routing::RouteSet.new

    @cache_path = File.expand_path("../tmp/test_cache", __FILE__)
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
    with_routing do |set|
      set.draw do
        get "/with_page_cache", to: "another/log_subscribers#with_page_cache"
      end

      get :with_page_cache
      wait

      logs = @logger.logged(:info)
      assert_equal 3, logs.size
      assert_match(/Write page/, logs[1])
      assert_match(/\/index\.html/, logs[1])
    end
  end
end
