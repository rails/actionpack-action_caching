module ActionController
  module Caching
    eager_autoload do
      autoload :Actions
    end

    include Actions
  end
end
