require 'rails/railtie'

module ActionPack
  module PageCachingMultithread
    class Railtie < Rails::Railtie
      initializer 'action_pack.page_caching_multithread' do
        ActiveSupport.on_load(:action_controller) do
          require 'action_controller/page_caching_multithread'
        end
      end

      initializer 'action_pack.page_caching_multithread.set_config', before: 'action_controller.set_configs' do |app|
        app.config.action_controller.page_cache_directory ||= app.config.paths['public'].first
      end
    end
  end
end
