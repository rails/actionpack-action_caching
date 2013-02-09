require 'abstract_unit'

CACHE_DIR = 'test_cache'
# Don't change '/../temp/' cavalierly or you might hose something you don't want hosed
FILE_STORE_PATH = File.join(File.dirname(__FILE__), '/../temp/', CACHE_DIR)

class CachingController < ActionController::Base
  abstract!

  self.cache_store = :file_store, FILE_STORE_PATH
end

class CachePath
  def call(controller)
    ['controller', controller.params[:id]].compact.join('-')
  end
end

class ActionCachingTestController < CachingController
  rescue_from(Exception) { head 500 }
  rescue_from(ActionController::UnknownFormat) { head :not_acceptable }
  if defined? ActiveRecord
    rescue_from(ActiveRecord::RecordNotFound) { head :not_found }
  end

  # Eliminate uninitialized ivar warning
  before_filter { @title = nil }

  caches_action :index, :redirected, :forbidden, if: Proc.new { |c| c.request.format && !c.request.format.json? }, expires_in: 1.hour
  caches_action :show, cache_path: 'http://test.host/custom/show'
  caches_action :edit, cache_path: Proc.new { |c| c.params[:id] ? "http://test.host/#{c.params[:id]};edit" : 'http://test.host/edit' }
  caches_action :custom_cache_path, cache_path: CachePath.new
  caches_action :with_layout
  caches_action :with_format_and_http_param, cache_path: Proc.new { |c| { key: 'value' } }
  caches_action :layout_false, layout: false
  caches_action :with_layout_proc_param, layout: Proc.new { |c| c.params[:layout] }
  caches_action :record_not_found, :four_oh_four, :simple_runtime_error
  caches_action :streaming
  caches_action :invalid

  layout 'talk_from_action'

  def index
    @cache_this = MockTime.now.to_f.to_s
    render text: @cache_this
  end

  def redirected
    redirect_to action: 'index'
  end

  def forbidden
    render text: 'Forbidden'
    response.status = '403 Forbidden'
  end

  def with_layout
    @cache_this = MockTime.now.to_f.to_s
    @title = nil
    render text: @cache_this, layout: true
  end

  def with_format_and_http_param
    @cache_this = MockTime.now.to_f.to_s
    render text: @cache_this
  end

  def record_not_found
    raise ActiveRecord::RecordNotFound, 'oops!'
  end

  def four_oh_four
    render text: "404'd!", status: 404
  end

  def simple_runtime_error
    raise 'oops!'
  end

  alias_method :show, :index
  alias_method :edit, :index
  alias_method :destroy, :index
  alias_method :custom_cache_path, :index
  alias_method :layout_false, :with_layout
  alias_method :with_layout_proc_param, :with_layout

  def expire
    expire_action controller: 'action_caching_test', action: 'index'
    render nothing: true
  end

  def expire_xml
    expire_action controller: 'action_caching_test', action: 'index', format: 'xml'
    render nothing: true
  end

  def expire_with_url_string
    expire_action url_for(controller: 'action_caching_test', action: 'index')
    render nothing: true
  end

  def streaming
    render text: 'streaming', stream: true
  end

  def invalid
    @cache_this = MockTime.now.to_f.to_s

    respond_to do |format|
      format.json{ render json: @cache_this }
    end
  end
end

class MockTime < Time
  # Let Time spicy to assure that Time.now != Time.now
  def to_f
    super+rand
  end
end

class ActionCachingMockController
  attr_accessor :mock_url_for
  attr_accessor :mock_path

  def initialize
    yield self if block_given?
  end

  def url_for(*args)
    @mock_url_for
  end

  def params
    request.parameters
  end

  def request
    Object.new.instance_eval(<<-EVAL)
      def path; '#{@mock_path}' end
      def format; 'all' end
      def parameters; { format: nil }; end
      self
    EVAL
  end
end

class ActionCacheTest < ActionController::TestCase
  tests ActionCachingTestController

  def setup
    super
    @request.host = 'hostname.com'
    FileUtils.mkdir_p(FILE_STORE_PATH)
    @path_class = ActionController::Caching::Actions::ActionCachePath
    @mock_controller = ActionCachingMockController.new
  end

  def teardown
    super
    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
  end

  def test_simple_action_cache_with_http_head
    head :index
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test')

    head :index
    assert_response :success
    assert_equal cached_time, @response.body
  end

  def test_simple_action_cache
    get :index
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test')

    get :index
    assert_response :success
    assert_equal cached_time, @response.body
  end

  def test_simple_action_not_cached
    get :destroy
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert !fragment_exist?('hostname.com/action_caching_test/destroy')

    get :destroy
    assert_response :success
    assert_not_equal cached_time, @response.body
  end

  include RackTestUtils

  def test_action_cache_with_layout
    get :with_layout
    assert_response :success
    cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test/with_layout')

    get :with_layout
    assert_response :success
    assert_not_equal cached_time, @response.body
    body = body_to_string(read_fragment('hostname.com/action_caching_test/with_layout'))
    assert_equal @response.body, body
  end

  def test_action_cache_with_layout_and_layout_cache_false
    get :layout_false
    assert_response :success
    cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test/layout_false')

    get :layout_false
    assert_response :success
    assert_not_equal cached_time, @response.body
    body = body_to_string(read_fragment('hostname.com/action_caching_test/layout_false'))
    assert_equal cached_time, body
  end

  def test_action_cache_with_layout_and_layout_cache_false_via_proc
    get :with_layout_proc_param, layout: false
    assert_response :success
    cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test/with_layout_proc_param')

    get :with_layout_proc_param, layout: false
    assert_response :success
    assert_not_equal cached_time, @response.body
    body = body_to_string(read_fragment('hostname.com/action_caching_test/with_layout_proc_param'))
    assert_equal cached_time, body
  end

  def test_action_cache_with_layout_and_layout_cache_true_via_proc
    get :with_layout_proc_param, layout: true
    assert_response :success
    cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test/with_layout_proc_param')

    get :with_layout_proc_param, layout: true
    assert_response :success
    assert_not_equal cached_time, @response.body
    body = body_to_string(read_fragment('hostname.com/action_caching_test/with_layout_proc_param'))
    assert_equal @response.body, body
  end

  def test_action_cache_conditional_options
    @request.env['HTTP_ACCEPT'] = 'application/json'
    get :index
    assert_response :success
    assert !fragment_exist?('hostname.com/action_caching_test')
  end

  def test_action_cache_with_format_and_http_param
    get :with_format_and_http_param, format: 'json'
    assert_response :success
    assert !fragment_exist?('hostname.com/action_caching_test/with_format_and_http_param.json?key=value.json')
    assert fragment_exist?('hostname.com/action_caching_test/with_format_and_http_param.json?key=value')
  end

  def test_action_cache_with_store_options
    MockTime.expects(:now).returns(12345).once
    @controller.expects(:read_fragment).with('hostname.com/action_caching_test', expires_in: 1.hour).once
    @controller.expects(:write_fragment).with('hostname.com/action_caching_test', '12345.0', expires_in: 1.hour).once
    get :index
    assert_response :success
  end

  def test_action_cache_with_custom_cache_path
    get :show
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?('test.host/custom/show')

    get :show
    assert_response :success
    assert_equal cached_time, @response.body
  end

  def test_action_cache_with_custom_cache_path_in_block
    get :edit
    assert_response :success
    assert fragment_exist?('test.host/edit')

    get :edit, id: 1
    assert_response :success
    assert fragment_exist?('test.host/1;edit')
  end

  def test_action_cache_with_custom_cache_path_with_custom_object
    get :custom_cache_path
    assert_response :success
    assert fragment_exist?('controller')

    get :custom_cache_path, id: 1
    assert_response :success
    assert fragment_exist?('controller-1')
  end

  def test_cache_expiration
    get :index
    assert_response :success
    cached_time = content_to_cache

    get :index
    assert_response :success
    assert_equal cached_time, @response.body

    get :expire
    assert_response :success

    get :index
    assert_response :success
    new_cached_time = content_to_cache
    assert_not_equal cached_time, @response.body

    get :index
    assert_response :success
    assert_equal new_cached_time, @response.body
  end

  def test_cache_expiration_isnt_affected_by_request_format
    get :index
    cached_time = content_to_cache

    @request.request_uri = "/action_caching_test/expire.xml"
    get :expire, format: :xml
    assert_response :success

    get :index
    assert_response :success
    assert_not_equal cached_time, @response.body
  end

  def test_cache_expiration_with_url_string
    get :index
    cached_time = content_to_cache

    @request.request_uri = "/action_caching_test/expire_with_url_string"
    get :expire_with_url_string
    assert_response :success

    get :index
    assert_response :success
    assert_not_equal cached_time, @response.body
  end

  def test_cache_is_scoped_by_subdomain
    @request.host = 'jamis.hostname.com'
    get :index
    assert_response :success
    jamis_cache = content_to_cache

    @request.host = 'david.hostname.com'
    get :index
    assert_response :success
    david_cache = content_to_cache
    assert_not_equal jamis_cache, @response.body

    @request.host = 'jamis.hostname.com'
    get :index
    assert_response :success
    assert_equal jamis_cache, @response.body

    @request.host = 'david.hostname.com'
    get :index
    assert_response :success
    assert_equal david_cache, @response.body
  end

  def test_redirect_is_not_cached
    get :redirected
    assert_response :redirect
    get :redirected
    assert_response :redirect
  end

  def test_forbidden_is_not_cached
    get :forbidden
    assert_response :forbidden
    get :forbidden
    assert_response :forbidden
  end

  def test_xml_version_of_resource_is_treated_as_different_cache
    with_routing do |set|
      set.draw do
        get ':controller(/:action(.:format))'
      end

      get :index, format: 'xml'
      assert_response :success
      cached_time = content_to_cache
      assert_equal cached_time, @response.body
      assert fragment_exist?('hostname.com/action_caching_test/index.xml')

      get :index, format: 'xml'
      assert_response :success
      assert_equal cached_time, @response.body
      assert_equal 'application/xml', @response.content_type

      get :expire_xml
      assert_response :success

      get :index, format: 'xml'
      assert_response :success
      assert_not_equal cached_time, @response.body
    end
  end

  def test_correct_content_type_is_returned_for_cache_hit
    # run it twice to cache it the first time
    get :index, id: 'content-type', format: 'xml'
    get :index, id: 'content-type', format: 'xml'
    assert_response :success
    assert_equal 'application/xml', @response.content_type
  end

  def test_correct_content_type_is_returned_for_cache_hit_on_action_with_string_key
    # run it twice to cache it the first time
    get :show, format: 'xml'
    get :show, format: 'xml'
    assert_response :success
    assert_equal 'application/xml', @response.content_type
  end

  def test_correct_content_type_is_returned_for_cache_hit_on_action_with_string_key_from_proc
    # run it twice to cache it the first time
    get :edit, id: 1, format: 'xml'
    get :edit, id: 1, format: 'xml'
    assert_response :success
    assert_equal 'application/xml', @response.content_type
  end

  def test_empty_path_is_normalized
    @mock_controller.mock_url_for = 'http://example.org/'
    @mock_controller.mock_path    = '/'

    assert_equal 'example.org/index', @path_class.new(@mock_controller, {}).path
  end

  def test_file_extensions
    get :index, id: 'kitten.jpg'
    get :index, id: 'kitten.jpg'

    assert_response :success
  end

  if defined? ActiveRecord
    def test_record_not_found_returns_404_for_multiple_requests
      get :record_not_found
      assert_response 404
      get :record_not_found
      assert_response 404
    end
  end

  def test_four_oh_four_returns_404_for_multiple_requests
    get :four_oh_four
    assert_response 404
    get :four_oh_four
    assert_response 404
  end

  def test_four_oh_four_renders_content
    get :four_oh_four
    assert_equal "404'd!", @response.body
  end

  def test_simple_runtime_error_returns_500_for_multiple_requests
    get :simple_runtime_error
    assert_response 500
    get :simple_runtime_error
    assert_response 500
  end

  def test_action_caching_plus_streaming
    get :streaming
    assert_response :success
    assert_match(/streaming/, @response.body)
    assert fragment_exist?('hostname.com/action_caching_test/streaming')
  end

  def test_invalid_format_returns_not_acceptable
    get :invalid, format: 'json'
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body

    assert fragment_exist?("hostname.com/action_caching_test/invalid.json")

    get :invalid, format: 'json'
    assert_response :success
    assert_equal cached_time, @response.body

    get :invalid, format: 'xml'
    assert_response :not_acceptable

    get :invalid, format: '\xC3\x83'
    assert_response :not_acceptable
  end

  private

    def content_to_cache
      assigns(:cache_this)
    end

    def fragment_exist?(path)
      @controller.fragment_exist?(path)
    end

    def read_fragment(path)
      @controller.read_fragment(path)
    end
end
