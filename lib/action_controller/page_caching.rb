# frozen_string_literal: true

require "action_controller/caching/pages"

module ActionController
  module Caching
    include Pages
  end
end

ActionController::Base.include(ActionController::Caching::Pages)
