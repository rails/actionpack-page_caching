require "abstract_unit"

module Another
  class InstrumentationController < ActionController::Base
    self.perform_caching = true

    def with_page_cache
      cache_page("Super soaker", "/index.html")
      head :ok
    end
  end
end

class InstrumentationTest < ActionController::TestCase
  tests Another::InstrumentationController

  def setup
    super

    @routes = ActionDispatch::Routing::RouteSet.new

    @cache_path = File.expand_path("../tmp/test_cache", __FILE__)
    ActionController::Base.page_cache_directory = @cache_path
  end

  def teardown
    FileUtils.rm_rf(@cache_path)
  end

  def test_write_page_is_instrumented
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("write_page.action_controller") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    with_routing do |set|
      set.draw do
        get "/with_page_cache", to: "another/instrumentation#with_page_cache"
      end

      get :with_page_cache
    end

    assert_equal 1, events.size
    assert_equal "/index.html", events.first.payload[:path]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def test_expire_page_is_instrumented
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("expire_page.action_controller") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    @controller.class.expire_page("/index.html")

    assert_equal 1, events.size
    assert_equal "/index.html", events.first.payload[:path]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
