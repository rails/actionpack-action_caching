require 'rails/railtie'

module ActionPack
  module ActionCaching
    class Railtie < Rails::Railtie
      initializer 'action_pack.action_caching' do
        ActiveSupport.on_load(:action_controller) do
          require 'action_controller/action_caching'
        end
      end
    end
  end
end
