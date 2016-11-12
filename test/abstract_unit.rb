require "bundler/setup"
require "minitest/autorun"
require "action_controller"
require "active_record"
require "action_controller/action_caching"

FIXTURE_LOAD_PATH = File.expand_path("../fixtures", __FILE__)

if ActiveSupport.respond_to?(:test_order)
  ActiveSupport.test_order = :random
end
