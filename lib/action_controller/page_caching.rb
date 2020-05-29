require "action_controller/caching/pages"

module ActionController
  module Caching
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Pages
    end

    include Pages
  end
end

ActionController::Base.send(:include, ActionController::Caching::Pages)
