require "action_controller/caching/actions"

module ActionController
  module Caching
    include Actions
  end
end

ActionController::Base.include(ActionController::Caching::Actions)
