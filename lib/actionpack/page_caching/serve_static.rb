module ActionPack
  module PageCaching
    class ServeStatic
        def initialize(app)
          @app = app
        end

        def call(env)
          if @app.config.action_controller.perform_caching
            cache_file =
                "#{@app.config.action_controller.page_cache_directory.to_s.gsub(/\/$/,'')}#{env['PATH_INFO']}.html"
            if File.exist?(cache_file) && File.readable?(cache_file)
              response = Rack::Response.new [File.read(cache_file)]
              return [200, response.headers, response.body]
            end
          end
          @app.call(env)
        end
    end
  end
end