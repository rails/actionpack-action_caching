require 'bundler/setup'
require 'minitest/autorun'
require 'action_controller'
require 'active_record'
require 'action_controller/action_caching'

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')


module ActionController
  class Base
    self.view_paths = FIXTURE_LOAD_PATH
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
