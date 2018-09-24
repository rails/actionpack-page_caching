require "fileutils"
require "uri"
require "active_support/core_ext/class/attribute_accessors"
require "active_support/core_ext/string/strip"

module ActionController
  module Caching
    # Page caching is an approach to caching where the entire action output of is
    # stored as a HTML file that the web server can serve without going through
    # Action Pack. This is the fastest way to cache your content as opposed to going
    # dynamically through the process of generating the content. Unfortunately, this
    # incredible speed-up is only available to stateless pages where all visitors are
    # treated the same. Content management systems -- including weblogs and wikis --
    # have many pages that are a great fit for this approach, but account-based systems
    # where people log in and manipulate their own data are often less likely candidates.
    #
    # Specifying which actions to cache is done through the +caches_page+ class method:
    #
    #   class WeblogController < ActionController::Base
    #     caches_page :show, :new
    #   end
    #
    # This will generate cache files such as <tt>weblog/show/5.html</tt> and
    # <tt>weblog/new.html</tt>, which match the URLs used that would normally trigger
    # dynamic page generation. Page caching works by configuring a web server to first
    # check for the existence of files on disk, and to serve them directly when found,
    # without passing the request through to Action Pack. This is much faster than
    # handling the full dynamic request in the usual way.
    #
    # Expiration of the cache is handled by deleting the cached file, which results
    # in a lazy regeneration approach where the cache is not restored before another
    # hit is made against it. The API for doing so mimics the options from +url_for+ and friends:
    #
    #   class WeblogController < ActionController::Base
    #     def update
    #       List.update(params[:list][:id], params[:list])
    #       expire_page action: "show", id: params[:list][:id]
    #       redirect_to action: "show", id: params[:list][:id]
    #     end
    #   end
    #
    # Additionally, you can expire caches using Sweepers that act on changes in
    # the model to determine when a cache is supposed to be expired.
    module Pages
      extend ActiveSupport::Concern

      included do
        # The cache directory should be the document root for the web server and is
        # set using <tt>Base.page_cache_directory = "/document/root"</tt>. For Rails,
        # this directory has already been set to Rails.public_path (which is usually
        # set to <tt>Rails.root + "/public"</tt>). Changing this setting can be useful
        # to avoid naming conflicts with files in <tt>public/</tt>, but doing so will
        # likely require configuring your web server to look in the new location for
        # cached files.
        class_attribute :page_cache_directory
        self.page_cache_directory ||= ""

        # The compression used for gzip. If +false+ (default), the page is not compressed.
        # If can be a symbol showing the ZLib compression method, for example, <tt>:best_compression</tt>
        # or <tt>:best_speed</tt> or an integer configuring the compression level.
        class_attribute :page_cache_compression
        self.page_cache_compression ||= false
      end

      class PageCache #:nodoc:
        def initialize(cache_directory, default_extension, controller = nil)
          @cache_directory = cache_directory
          @default_extension = default_extension
          @controller = controller
        end

        def expire(path)
          instrument :expire_page, path do
            delete(cache_path(path))
          end
        end

        def cache(content, path, extension = nil, gzip = Zlib::BEST_COMPRESSION)
          instrument :write_page, path do
            write(content, cache_path(path, extension), gzip)
          end
        end

        private
          def cache_directory
            case @cache_directory
            when Proc
              handle_proc_cache_directory
            when Symbol
              handle_symbol_cache_directory
            else
              handle_default_cache_directory
            end
          end

          def handle_proc_cache_directory
            if @controller
              @controller.instance_exec(&@cache_directory)
            else
              raise_runtime_error
            end
          end

          def handle_symbol_cache_directory
            if @controller
              @controller.send(@cache_directory)
            else
              raise_runtime_error
            end
          end

          def handle_callable_cache_directory
            if @controller
              @cache_directory.call(@controller.request)
            else
              raise_runtime_error
            end
          end

          def handle_default_cache_directory
            if @cache_directory.respond_to?(:call)
              handle_callable_cache_directory
            else
              @cache_directory.to_s
            end
          end

          def raise_runtime_error
            raise RuntimeError, <<-MSG.strip_heredoc
              Dynamic page_cache_directory used with class-level cache_page method

              You have specified either a Proc, Symbol or callable object for page_cache_directory
              which needs to be executed within the context of a request. If you need to call the
              cache_page method from a class-level context then set the page_cache_directory to a
              static value and override the setting at the instance-level using before_action.
            MSG
          end

          def default_extension
            @default_extension
          end

          def cache_file(path, extension)
            if path.empty? || path =~ %r{\A/+\z}
              name = "/index"
            else
              name = URI.parser.unescape(path.chomp("/"))
            end

            if File.extname(name).empty?
              name + (extension || default_extension)
            else
              name
            end
          end

          def cache_path(path, extension = nil)
            File.join(cache_directory, cache_file(path, extension))
          end

          def delete(path)
            File.delete(path) if File.exist?(path)
            File.delete(path + ".gz") if File.exist?(path + ".gz")
          end

          def write(content, path, gzip)
            FileUtils.makedirs(File.dirname(path))
            File.open(path, "wb+") { |f| f.write(content) }

            if gzip
              Zlib::GzipWriter.open(path + ".gz", gzip) { |f| f.write(content) }
            end
          end

          def instrument(name, path)
            ActiveSupport::Notifications.instrument("#{name}.action_controller", path: path) { yield }
          end
      end

      module ClassMethods
        # Expires the page that was cached with the +path+ as a key.
        #
        #   expire_page "/lists/show"
        def expire_page(path)
          if perform_caching
            page_cache.expire(path)
          end
        end

        # Manually cache the +content+ in the key determined by +path+.
        #
        #   cache_page "I'm the cached content", "/lists/show"
        def cache_page(content, path, extension = nil, gzip = Zlib::BEST_COMPRESSION)
          if perform_caching
            page_cache.cache(content, path, extension, gzip)
          end
        end

        # Caches the +actions+ using the page-caching approach that'll store
        # the cache in a path within the +page_cache_directory+ that
        # matches the triggering url.
        #
        # You can also pass a <tt>:gzip</tt> option to override the class configuration one.
        #
        #   # cache the index action
        #   caches_page :index
        #
        #   # cache the index action except for JSON requests
        #   caches_page :index, if: Proc.new { !request.format.json? }
        #
        #   # don't gzip images
        #   caches_page :image, gzip: false
        def caches_page(*actions)
          if perform_caching
            options = actions.extract_options!

            gzip_level = options.fetch(:gzip, page_cache_compression)
            gzip_level = \
              case gzip_level
              when Symbol
                Zlib.const_get(gzip_level.upcase)
              when Integer
                gzip_level
              when false
                nil
              else
                Zlib::BEST_COMPRESSION
              end

            after_action({ only: actions }.merge(options)) do |c|
              c.cache_page(nil, nil, gzip_level)
            end
          end
        end

        private
          def page_cache
            PageCache.new(page_cache_directory, default_static_extension)
          end
      end

      # Expires the page that was cached with the +options+ as a key.
      #
      #   expire_page controller: "lists", action: "show"
      def expire_page(options = {})
        if perform_caching?
          case options
          when Hash
            case options[:action]
            when Array
              options[:action].each { |action| expire_page(options.merge(action: action)) }
            else
              page_cache.expire(url_for(options.merge(only_path: true)))
            end
          else
            page_cache.expire(options)
          end
        end
      end

      # Manually cache the +content+ in the key determined by +options+. If no content is provided,
      # the contents of response.body is used. If no options are provided, the url of the current
      # request being handled is used.
      #
      #   cache_page "I'm the cached content", controller: "lists", action: "show"
      def cache_page(content = nil, options = nil, gzip = Zlib::BEST_COMPRESSION)
        if perform_caching? && caching_allowed?
          path = \
            case options
            when Hash
              url_for(options.merge(only_path: true, format: params[:format]))
            when String
              options
            else
              request.path
            end

          if (type = Mime::LOOKUP[self.content_type]) && (type_symbol = type.symbol).present?
            extension = ".#{type_symbol}"
          end

          page_cache.cache(content || response.body, path, extension, gzip)
        end
      end

      def caching_allowed?
        (request.get? || request.head?) && response.status == 200
      end

      def perform_caching?
        self.class.perform_caching
      end

      private
        def page_cache
          PageCache.new(page_cache_directory, default_static_extension, self)
        end
    end
  end
end
