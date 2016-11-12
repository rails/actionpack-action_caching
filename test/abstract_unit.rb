require 'bundler/setup'
require 'minitest/autorun'
require 'action_controller'
require 'active_record'
require 'action_controller/action_caching'

FIXTURE_LOAD_PATH = File.expand_path('../fixtures', __FILE__)

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
