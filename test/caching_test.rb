require "abstract_unit"
require "mocha/setup"

CACHE_DIR = "test_cache"
# Don't change "../tmp" cavalierly or you might hose something you don't want hosed
TEST_TMP_DIR = File.expand_path("../tmp", __FILE__)
FILE_STORE_PATH = File.join(TEST_TMP_DIR, CACHE_DIR)

module PageCachingTestHelpers
  def setup
    super

    @routes = ActionDispatch::Routing::RouteSet.new

    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
    FileUtils.mkdir_p(FILE_STORE_PATH)
  end

  def teardown
    super

    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
    @controller.perform_caching = false
  end

  private

    def assert_page_cached(action, options = {}, query_string = nil)
      expected = options[:content] || action.to_s
      path = cache_file(action, options, query_string)
      assert File.exist?(path), "The cache file #{path} doesn't exist"

      if File.extname(path) == ".gz"
        actual = Zlib::GzipReader.open(path) { |f| f.read }
      else
        actual = File.read(path)
      end

      assert_equal expected, actual, "The cached content doesn't match the expected value"
    end

    def assert_page_not_cached(action, options = {}, query_string = nil)
      path = cache_file(action, options, query_string)
      assert !File.exist?(path), "The cache file #{path} still exists"
    end

    def cache_file(action, options = {}, query_string = nil)
      path = options[:path] || FILE_STORE_PATH
      controller = options[:controller] || self.class.name.underscore
      format = options[:format] || "html"
      query = query_string.present? ? "?#{query_string}" : ''

      "#{path}/#{controller}/#{action}.#{format}#{query}"
    end

    def draw(&block)
      @routes = ActionDispatch::Routing::RouteSet.new
      @routes.draw(&block)
      @controller.extend(@routes.url_helpers)
    end
end

class CachingMetalController < ActionController::Metal
  abstract!

  include AbstractController::Callbacks
  include ActionController::Caching

  self.page_cache_directory = FILE_STORE_PATH
  self.cache_store = :file_store, FILE_STORE_PATH
end

class PageCachingMetalTestController < CachingMetalController
  caches_page :ok

  def ok
    self.response_body = "ok"
  end
end

class PageCachingMetalTest < ActionController::TestCase
  include PageCachingTestHelpers
  tests PageCachingMetalTestController

  def test_should_cache_get_with_ok_status
    draw do
      get "/page_caching_metal_test/ok", to: "page_caching_metal_test#ok"
    end

    get :ok
    assert_response :ok
    assert_page_cached :ok
  end
end

ActionController::Base.page_cache_directory = FILE_STORE_PATH

class CachingController < ActionController::Base
  abstract!

  self.cache_store = :file_store, FILE_STORE_PATH

  protected
    if ActionPack::VERSION::STRING < "4.1"
      def render(options)
        if options.key?(:html)
          super({ text: options.delete(:html) }.merge(options))
        else
          super
        end
      end
    end
end

class PageCachingTestController < CachingController
  self.page_cache_compression = :best_compression

  caches_page :ok, :no_content, if: Proc.new { |c| !c.request.format.json? }
  caches_page :found, :not_found
  caches_page :about_me
  caches_page :default_gzip
  caches_page :no_gzip, gzip: false
  caches_page :gzip_level, gzip: :best_speed

  def ok
    render html: "ok"
  end

  def no_content
    head :no_content
  end

  def found
    redirect_to action: "ok"
  end

  def not_found
    head :not_found
  end

  def custom_path
    render html: "custom_path"
    cache_page(nil, "/index.html")
  end

  def default_gzip
    render html: "default_gzip"
  end

  def no_gzip
    render html: "no_gzip"
  end

  def gzip_level
    render html: "gzip_level"
  end

  def expire_custom_path
    expire_page("/index.html")
    head :ok
  end

  def trailing_slash
    render html: "trailing_slash"
  end

  def about_me
    respond_to do |format|
      format.html { render html: "I am html" }
      format.xml  { render xml: "I am xml" }
    end
  end
end

class PageCachingTest < ActionController::TestCase
  include PageCachingTestHelpers
  tests PageCachingTestController

  def test_page_caching_resources_saves_to_correct_path_with_extension_even_if_default_route
    draw do
      get "posts.:format", to: "posts#index", as: :formatted_posts
      get "/", to: "posts#index", as: :main
    end

    defaults = { controller: "posts", action: "index", only_path: true }

    assert_equal "/posts.rss", @routes.url_for(defaults.merge(format: "rss"))
    assert_equal "/", @routes.url_for(defaults.merge(format: nil))
  end

  def test_should_cache_head_with_ok_status
    draw do
      get "/page_caching_test/ok", to: "page_caching_test#ok"
    end

    head :ok
    assert_response :ok
    assert_page_cached :ok
  end

  def test_should_cache_get_with_ok_status
    draw do
      get "/page_caching_test/ok", to: "page_caching_test#ok"
    end

    get :ok
    assert_response :ok
    assert_page_cached :ok
  end

  def test_should_cache_with_custom_path
    draw do
      get "/page_caching_test/custom_path", to: "page_caching_test#custom_path"
    end

    get :custom_path
    assert_page_cached :index, controller: ".", content: "custom_path"
  end

  def test_should_expire_cache_with_custom_path
    draw do
      get "/page_caching_test/custom_path", to: "page_caching_test#custom_path"
      get "/page_caching_test/expire_custom_path", to: "page_caching_test#expire_custom_path"
    end

    get :custom_path
    assert_page_cached :index, controller: ".", content: "custom_path"

    get :expire_custom_path
    assert_page_not_cached :index, controller: ".", content: "custom_path"
  end

  def test_should_gzip_cache
    draw do
      get "/page_caching_test/custom_path", to: "page_caching_test#custom_path"
      get "/page_caching_test/expire_custom_path", to: "page_caching_test#expire_custom_path"
    end

    get :custom_path
    assert_page_cached :index, controller: ".", format: "html.gz", content: "custom_path"

    get :expire_custom_path
    assert_page_not_cached :index, controller: ".", format: "html.gz"
  end

  def test_should_allow_to_disable_gzip
    draw do
      get "/page_caching_test/no_gzip", to: "page_caching_test#no_gzip"
    end

    get :no_gzip
    assert_page_cached :no_gzip, format: "html"
    assert_page_not_cached :no_gzip, format: "html.gz"
  end

  def test_should_use_config_gzip_by_default
    draw do
      get "/page_caching_test/default_gzip", to: "page_caching_test#default_gzip"
    end

    @controller.expects(:cache_page).with(nil, nil, Zlib::BEST_COMPRESSION, false)
    get :default_gzip
  end

  def test_should_set_gzip_level
    draw do
      get "/page_caching_test/gzip_level", to: "page_caching_test#gzip_level"
    end

    @controller.expects(:cache_page).with(nil, nil, Zlib::BEST_SPEED, false)
    get :gzip_level
  end

  def test_should_cache_without_trailing_slash_on_url
    @controller.class.cache_page "cached content", "/page_caching_test/trailing_slash"
    assert_page_cached :trailing_slash, content: "cached content"
  end

  def test_should_obey_http_accept_attribute
    draw do
      get "/page_caching_test/about_me", to: "page_caching_test#about_me"
    end

    @request.env["HTTP_ACCEPT"] = "text/xml"
    get :about_me
    assert_equal "I am xml", @response.body
    assert_page_cached :about_me, format: "xml", content: "I am xml"
  end

  def test_cached_page_should_not_have_trailing_slash_even_if_url_has_trailing_slash
    @controller.class.cache_page "cached content", "/page_caching_test/trailing_slash/"
    assert_page_cached :trailing_slash, content: "cached content"
  end

  def test_should_cache_ok_at_custom_path
    draw do
      get "/page_caching_test/ok", to: "page_caching_test#ok"
    end

    @request.env["PATH_INFO"] = "/index.html"
    get :ok
    assert_response :ok
    assert_page_cached :index, controller: ".", content: "ok"
  end

  [:ok, :no_content, :found, :not_found].each do |status|
    [:get, :post, :patch, :put, :delete].each do |method|
      unless method == :get && status == :ok
        define_method "test_shouldnt_cache_#{method}_with_#{status}_status" do
          draw do
            get "/page_caching_test/ok", to: "page_caching_test#ok"
            match "/page_caching_test/#{status}", to: "page_caching_test##{status}", via: method
          end

          send(method, status)
          assert_response status
          assert_page_not_cached status
        end
      end
    end
  end

  def test_page_caching_conditional_options
    draw do
      get "/page_caching_test/ok", to: "page_caching_test#ok"
    end

    get :ok, format: "json"
    assert_page_not_cached :ok
  end

  def test_page_caching_directory_set_as_pathname
    begin
      ActionController::Base.page_cache_directory = Pathname.new(FILE_STORE_PATH)

      draw do
        get "/page_caching_test/ok", to: "page_caching_test#ok"
      end

      get :ok
      assert_response :ok
      assert_page_cached :ok
    ensure
      ActionController::Base.page_cache_directory = FILE_STORE_PATH
    end
  end

  def test_page_caching_directory_set_on_controller_instance
    draw do
      get "/page_caching_test/ok", to: "page_caching_test#ok"
    end

    file_store_path = File.join(TEST_TMP_DIR, "instance_cache")
    @controller.page_cache_directory = file_store_path

    get :ok
    assert_response :ok
    assert_page_cached :ok, path: file_store_path
  end
end

class ProcPageCachingTestController < CachingController
  self.page_cache_directory = -> { File.join(TEST_TMP_DIR, request.domain) }

  caches_page :ok

  def ok
    render html: "ok"
  end

  def expire_ok
    expire_page action: :ok
    head :ok
  end
end

class ProcPageCachingTest < ActionController::TestCase
  include PageCachingTestHelpers
  tests ProcPageCachingTestController

  def test_page_is_cached_by_domain
    draw do
      get "/proc_page_caching_test/ok", to: "proc_page_caching_test#ok"
      get "/proc_page_caching_test/ok/expire", to: "proc_page_caching_test#expire_ok"
    end

    @request.env["HTTP_HOST"] = "www.foo.com"
    get :ok
    assert_response :ok
    assert_page_cached :ok, path: TEST_TMP_DIR + "/foo.com"

    get :expire_ok
    assert_response :ok
    assert_page_not_cached :ok, path: TEST_TMP_DIR + "/foo.com"

    @request.env["HTTP_HOST"] = "www.bar.com"
    get :ok
    assert_response :ok
    assert_page_cached :ok, path: TEST_TMP_DIR + "/bar.com"

    get :expire_ok
    assert_response :ok
    assert_page_not_cached :ok, path: TEST_TMP_DIR + "/bar.com"
  end

  def test_class_level_cache_page_raise_error
    assert_raises(RuntimeError, /class-level cache_page method/) do
      @controller.class.cache_page "cached content", "/proc_page_caching_test/ok"
    end
  end
end

class SymbolPageCachingTestController < CachingController
  self.page_cache_directory = :domain_cache_directory

  caches_page :ok

  def ok
    render html: "ok"
  end

  def expire_ok
    expire_page action: :ok
    head :ok
  end

  protected
    def domain_cache_directory
      File.join(TEST_TMP_DIR, request.domain)
    end
end

class SymbolPageCachingTest < ActionController::TestCase
  include PageCachingTestHelpers
  tests SymbolPageCachingTestController

  def test_page_is_cached_by_domain
    draw do
      get "/symbol_page_caching_test/ok", to: "symbol_page_caching_test#ok"
      get "/symbol_page_caching_test/ok/expire", to: "symbol_page_caching_test#expire_ok"
    end

    @request.env["HTTP_HOST"] = "www.foo.com"
    get :ok
    assert_response :ok
    assert_page_cached :ok, path: TEST_TMP_DIR + "/foo.com"

    get :expire_ok
    assert_response :ok
    assert_page_not_cached :ok, path: TEST_TMP_DIR + "/foo.com"

    @request.env["HTTP_HOST"] = "www.bar.com"
    get :ok
    assert_response :ok
    assert_page_cached :ok, path: TEST_TMP_DIR + "/bar.com"

    get :expire_ok
    assert_response :ok
    assert_page_not_cached :ok, path: TEST_TMP_DIR + "/bar.com"
  end

  def test_class_level_cache_page_raise_error
    assert_raises(RuntimeError, /class-level cache_page method/) do
      @controller.class.cache_page "cached content", "/symbol_page_caching_test/ok"
    end
  end
end

class CallablePageCachingTestController < CachingController
  class DomainCacheDirectory
    def self.call(request)
      File.join(TEST_TMP_DIR, request.domain)
    end
  end

  self.page_cache_directory = DomainCacheDirectory

  caches_page :ok

  def ok
    render html: "ok"
  end

  def expire_ok
    expire_page action: :ok
    head :ok
  end
end

class CallablePageCachingTest < ActionController::TestCase
  include PageCachingTestHelpers
  tests CallablePageCachingTestController

  def test_page_is_cached_by_domain
    draw do
      get "/callable_page_caching_test/ok", to: "callable_page_caching_test#ok"
      get "/callable_page_caching_test/ok/expire", to: "callable_page_caching_test#expire_ok"
    end

    @request.env["HTTP_HOST"] = "www.foo.com"
    get :ok
    assert_response :ok
    assert_page_cached :ok, path: TEST_TMP_DIR + "/foo.com"

    get :expire_ok
    assert_response :ok
    assert_page_not_cached :ok, path: TEST_TMP_DIR + "/foo.com"

    @request.env["HTTP_HOST"] = "www.bar.com"
    get :ok
    assert_response :ok
    assert_page_cached :ok, path: TEST_TMP_DIR + "/bar.com"

    get :expire_ok
    assert_response :ok
    assert_page_not_cached :ok, path: TEST_TMP_DIR + "/bar.com"
  end

  def test_class_level_cache_page_raise_error
    assert_raises(RuntimeError, /class-level cache_page method/) do
      @controller.class.cache_page "cached content", "/callable_page_caching_test/ok"
    end
  end
end

class WithQueryPageCachingSetTestController < CachingController
  self.page_cache_with_query_string = true

  caches_page :default
  caches_page :without_query, with_query_string: false

  def default
    render html: "default"
  end

  def without_query
    render html: "without_query"
  end

  def expire_default
    expire_page action: :default
    head :ok
  end
end

class WithQueryPageCachingSetTest < ActionController::TestCase
  include PageCachingTestHelpers
  tests WithQueryPageCachingSetTestController

  def test_cached_file_name_includes_query_string
    draw do
      get "/with_query_page_caching_set_test/default", to: "with_query_page_caching_set_test#default"
    end
    get :default, params: {variant: '1', with: 'data'}
    assert_page_cached :default, {}, 'variant=1&with=data'
    assert_page_not_cached :default
  end

  def test_request_without_query_generates_cache_file_name_without_query
    draw do
      get "/with_query_page_caching_set_test/default", to: "with_query_page_caching_set_test#default"
    end
    get :default
    assert_page_cached :default
  end

  def test_should_cache_one_file_per_query_variant
    draw do
      get "/with_query_page_caching_set_test/default", to: "with_query_page_caching_set_test#default"
    end

    get :default, params: {variant: '1'}
    get :default, params: {variant: '2'}
    assert_page_cached :default, {}, 'variant=1'
    assert_page_cached :default, {}, 'variant=2'
  end

  def test_inline_option_takes_over_controller_setting
    draw do
      get "/with_query_page_caching_set_test/without_query", to: "with_query_page_caching_set_test#without_query"
    end

    get :without_query, params: {variant: '1', with: 'data'}
    assert_page_not_cached :without_query, {}, 'variant=1&with=data'
    assert_page_cached :without_query
  end

  def test_should_expire_all_query_variants
    draw do
      get "/with_query_page_caching_set_test/default", to: "with_query_page_caching_set_test#default"
      get "/with_query_page_caching_set_test/expire_default", to: "with_query_page_caching_set_test#expire_default"
    end

    get :default
    get :default, params: {variant: '1'}
    get :default, params: {variant: '2'}
    assert_page_cached :default
    assert_page_cached :default, {}, 'variant=1'
    assert_page_cached :default, {}, 'variant=2'

    get :expire_default
    assert_page_not_cached :default
    assert_page_not_cached :default, {}, 'variant=1'
    assert_page_not_cached :default, {}, 'variant=2'
  end
end

class WithQueryPageCachingNotSetTestController < CachingController
  caches_page :default
  caches_page :with_query, with_query_string: true

  def default
    render html: "default"
  end

  def with_query
    render html: "with_query"
  end
end

class WithQueryPageCachingNotSetTest < ActionController::TestCase
  include PageCachingTestHelpers
  tests WithQueryPageCachingNotSetTestController

  def test_ignore_query_string_by_default
    draw do
      get "/with_query_page_caching_not_set_test/default", to: "with_query_page_caching_not_set_test#default"
    end

    get :default, params: {variant: '1', with: 'data'}
    assert_page_not_cached :default, {}, 'variant=1&with=data'
    assert_page_cached :default
  end

  def test_with_query_string_option_enabled
    draw do
      get "/with_query_page_caching_not_set_test/with_query", to: "with_query_page_caching_not_set_test#with_query"
    end

    get :with_query, params: {variant: '1', with: 'data'}
    assert_page_not_cached :with_query
    assert_page_cached :with_query, {}, 'variant=1&with=data'
  end
end
