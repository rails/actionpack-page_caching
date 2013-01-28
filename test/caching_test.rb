require 'abstract_unit'

CACHE_DIR = 'test_cache'
# Don't change '/../temp/' cavalierly or you might hose something you don't want hosed
FILE_STORE_PATH = File.join(File.dirname(__FILE__), '/../temp/', CACHE_DIR)

class CachingMetalController < ActionController::Metal
  abstract!

  include ActionController::Caching

  self.page_cache_directory = FILE_STORE_PATH
  self.cache_store = :file_store, FILE_STORE_PATH
end

class PageCachingMetalTestController < CachingMetalController
  caches_page :ok

  def ok
    self.response_body = 'ok'
  end
end

class PageCachingMetalTest < ActionController::TestCase
  tests PageCachingMetalTestController

  def setup
    super

    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
    FileUtils.mkdir_p(FILE_STORE_PATH)
  end

  def teardown
    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
  end

  def test_should_cache_get_with_ok_status
    get :ok
    assert_response :ok
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_metal_test/ok.html"), 'get with ok status should have been cached'
  end
end

ActionController::Base.page_cache_directory = FILE_STORE_PATH

class CachingController < ActionController::Base
  abstract!

  self.cache_store = :file_store, FILE_STORE_PATH
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
    head :ok
  end

  def no_content
    head :no_content
  end

  def found
    redirect_to action: 'ok'
  end

  def not_found
    head :not_found
  end

  def custom_path
    render text: 'Super soaker'
    cache_page('Super soaker', '/index.html')
  end

  def default_gzip
    render text: 'Text'
  end

  def no_gzip
    render text: 'PNG'
  end

  def gzip_level
    render text: 'Big text'
  end

  def expire_custom_path
    expire_page('/index.html')
    head :ok
  end

  def trailing_slash
    render text: 'Sneak attack'
  end

  def about_me
    respond_to do |format|
      format.html { render text: 'I am html' }
      format.xml  { render text: 'I am xml'  }
    end
  end
end

class PageCachingTest < ActionController::TestCase
  def setup
    super

    @request = ActionController::TestRequest.new
    @request.host = 'hostname.com'
    @request.env.delete('PATH_INFO')

    @controller = PageCachingTestController.new
    @controller.perform_caching = true
    @controller.cache_store = :file_store, FILE_STORE_PATH

    @response   = ActionController::TestResponse.new

    @params = { controller: 'posts', action: 'index', only_path: true }

    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
    FileUtils.mkdir_p(FILE_STORE_PATH)
  end

  def teardown
    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
    @controller.perform_caching = false
  end

  def test_page_caching_resources_saves_to_correct_path_with_extension_even_if_default_route
    with_routing do |set|
      set.draw do
        get 'posts.:format', to: 'posts#index', as: :formatted_posts
        get '/', to: 'posts#index', as: :main
      end
      @params[:format] = 'rss'
      assert_equal '/posts.rss', @routes.url_for(@params)
      @params[:format] = nil
      assert_equal '/', @routes.url_for(@params)
    end
  end

  def test_should_cache_head_with_ok_status
    head :ok
    assert_response :ok
    assert_page_cached :ok, 'head with ok status should have been cached'
  end

  def test_should_cache_get_with_ok_status
    get :ok
    assert_response :ok
    assert_page_cached :ok, 'get with ok status should have been cached'
  end

  def test_should_cache_with_custom_path
    get :custom_path
    assert File.exist?("#{FILE_STORE_PATH}/index.html")
  end

  def test_should_expire_cache_with_custom_path
    get :custom_path
    assert File.exist?("#{FILE_STORE_PATH}/index.html")

    get :expire_custom_path
    assert !File.exist?("#{FILE_STORE_PATH}/index.html")
  end

  def test_should_gzip_cache
    get :custom_path
    assert File.exist?("#{FILE_STORE_PATH}/index.html.gz")

    get :expire_custom_path
    assert !File.exist?("#{FILE_STORE_PATH}/index.html.gz")
  end

  def test_should_allow_to_disable_gzip
    get :no_gzip
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_test/no_gzip.html")
    assert !File.exist?("#{FILE_STORE_PATH}/page_caching_test/no_gzip.html.gz")
  end

  def test_should_use_config_gzip_by_default
    @controller.expects(:cache_page).with(nil, nil, Zlib::BEST_COMPRESSION)
    get :default_gzip
  end

  def test_should_set_gzip_level
    @controller.expects(:cache_page).with(nil, nil, Zlib::BEST_SPEED)
    get :gzip_level
  end

  def test_should_cache_without_trailing_slash_on_url
    @controller.class.cache_page 'cached content', '/page_caching_test/trailing_slash'
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_test/trailing_slash.html")
  end

  def test_should_obey_http_accept_attribute
    @request.env['HTTP_ACCEPT'] = 'text/xml'
    get :about_me
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_test/about_me.xml")
    assert_equal 'I am xml', @response.body
  end

  def test_cached_page_should_not_have_trailing_slash_even_if_url_has_trailing_slash
    @controller.class.cache_page 'cached content', '/page_caching_test/trailing_slash/'
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_test/trailing_slash.html")
  end

  def test_should_cache_ok_at_custom_path
    @request.env['PATH_INFO'] = '/index.html'
    get :ok
    assert_response :ok
    assert File.exist?("#{FILE_STORE_PATH}/index.html")
  end

  [:ok, :no_content, :found, :not_found].each do |status|
    [:get, :post, :patch, :put, :delete].each do |method|
      unless method == :get && status == :ok
        define_method "test_shouldnt_cache_#{method}_with_#{status}_status" do
          send(method, status)
          assert_response status
          assert_page_not_cached status, "#{method} with #{status} status shouldn't have been cached"
        end
      end
    end
  end

  def test_page_caching_conditional_options
    get :ok, format: 'json'
    assert_page_not_cached :ok
  end

  def test_page_caching_directory_set_as_pathname
    begin
      ActionController::Base.page_cache_directory = Pathname.new(FILE_STORE_PATH)
      get :ok
      assert_response :ok
      assert_page_cached :ok
    ensure
      ActionController::Base.page_cache_directory = FILE_STORE_PATH
    end
  end

  private

    def assert_page_cached(action, message = "#{action} should have been cached")
      assert page_cached?(action), message
    end

    def assert_page_not_cached(action, message = "#{action} shouldn't have been cached")
      assert !page_cached?(action), message
    end

    def page_cached?(action)
      File.exist? "#{FILE_STORE_PATH}/page_caching_test/#{action}.html"
    end
end
