module ActionController
  module Caching
    eager_autoload do
      autoload :Pages
    end

    include Pages
  end
end
