require 'bundler/setup'
require 'minitest/autorun'
require 'action_controller'
require 'active_record'
require 'action_controller/action_caching'

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')

SharedTestRoutes = ActionDispatch::Routing::RouteSet.new

module ActionController
  class Base
    include SharedTestRoutes.url_helpers

    self.view_paths = FIXTURE_LOAD_PATH
  end

  class TestCase
    def setup
      @routes = SharedTestRoutes

      @routes.draw do
        get ':controller(/:action)'
      end
    end
  end
end

module RackTestUtils
  def body_to_string(body)
    if body.respond_to?(:each)
      str = ''
      body.each {|s| str << s }
      str
    else
      body
    end
  end
  extend self
end
