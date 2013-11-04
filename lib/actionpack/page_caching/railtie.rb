require 'rails/railtie'

module ActionPack
  module PageCaching
    class Railtie < Rails::Railtie
      initializer 'action_pack.page_caching' do |app|
        ActiveSupport.on_load(:action_controller) do
          require 'action_controller/caching/pages'

          include ActionController::Caching::Pages
        end
      end

      initializer 'action_pack.page_caching.set_config', before: 'action_controller.set_configs' do |app|
        app.config.action_controller.page_cache_directory ||= app.config.paths['public'].first
      end
    end
  end
end
