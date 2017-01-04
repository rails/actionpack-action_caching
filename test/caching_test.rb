require "abstract_unit"
require "mocha/setup"

CACHE_DIR = "test_cache"
# Don't change "../tmp" cavalierly or you might hose something you don't want hosed
TEST_TMP_DIR = File.expand_path("../tmp", __FILE__)
FILE_STORE_PATH = File.join(TEST_TMP_DIR, CACHE_DIR)

class CachingController < ActionController::Base
  abstract!

  self.cache_store = :file_store, FILE_STORE_PATH
end

class CachePath
  def call(controller)
    ["controller", controller.params[:id]].compact.join("-")
  end
end

class ActionCachingTestController < CachingController
  rescue_from(Exception) { head 500 }
  rescue_from(ActionController::UnknownFormat) { head :not_acceptable }
  if defined? ActiveRecord
    rescue_from(ActiveRecord::RecordNotFound) { head :not_found }
  end

  self.view_paths = FIXTURE_LOAD_PATH

  before_action only: :with_symbol_format do
    request.params[:format] = :json
  end

  caches_action :index, :redirected, :forbidden, if: ->(c) { c.request.format && !c.request.format.json? }, expires_in: 1.hour
  caches_action :show, cache_path: "http://test.host/custom/show"
  caches_action :edit, cache_path: ->(c) { c.params[:id] ? "http://test.host/#{c.params[:id]};edit" : "http://test.host/edit" }
  caches_action :custom_cache_path, cache_path: CachePath.new
  caches_action :symbol_cache_path, cache_path: :cache_path_protected_method
  caches_action :with_layout
  caches_action :with_format_and_http_param, cache_path: ->(c) { { key: "value" } }
  caches_action :with_symbol_format, cache_path: "http://test.host/action_caching_test/with_symbol_format"
  caches_action :not_url_cache_path, cache_path: ->(c) { "#{c.params[:action]}_key" }
  caches_action :not_url_cache_path_no_args, cache_path: -> { "#{params[:action]}_key" }
  caches_action :layout_false, layout: false
  caches_action :with_layout_proc_param, layout: ->(c) { c.params[:layout] != "false" }
  caches_action :with_layout_proc_param_no_args, layout: -> { params[:layout] != "false" }
  caches_action :record_not_found, :four_oh_four, :simple_runtime_error
  caches_action :streaming
  caches_action :invalid
  caches_action :accept

  layout "talk_from_action"

  def index
    @cache_this = MockTime.now.to_f.to_s
    render plain: @cache_this
  end

  def redirected
    redirect_to action: "index"
  end

  def forbidden
    render plain: "Forbidden"
    response.status = "403 Forbidden"
  end

  def with_layout
    @cache_this = MockTime.now.to_f.to_s
    render html: @cache_this, layout: true
  end

  def with_format_and_http_param
    @cache_this = MockTime.now.to_f.to_s
    render plain: @cache_this
  end

  def with_symbol_format
    @cache_this = MockTime.now.to_f.to_s
    render json: { timestamp: @cache_this }
  end

  def not_url_cache_path
    render plain: "cache_this"
  end
  alias_method :not_url_cache_path_no_args, :not_url_cache_path

  def record_not_found
    raise ActiveRecord::RecordNotFound, "oops!"
  end

  def four_oh_four
    render plain: "404'd!", status: 404
  end

  def simple_runtime_error
    raise "oops!"
  end

  alias_method :show, :index
  alias_method :edit, :index
  alias_method :destroy, :index
  alias_method :custom_cache_path, :index
  alias_method :symbol_cache_path, :index
  alias_method :layout_false, :with_layout
  alias_method :with_layout_proc_param, :with_layout
  alias_method :with_layout_proc_param_no_args, :with_layout

  def expire
    expire_action controller: "action_caching_test", action: "index"
    head :ok
  end

  def expire_xml
    expire_action controller: "action_caching_test", action: "index", format: "xml"
    head :ok
  end

  def expire_with_url_string
    expire_action url_for(controller: "action_caching_test", action: "index")
    head :ok
  end

  def streaming
    render plain: "streaming", stream: true
  end

  def invalid
    @cache_this = MockTime.now.to_f.to_s

    respond_to do |format|
      format.json { render json: @cache_this }
    end
  end

  def accept
    @cache_this = MockTime.now.to_f.to_s

    respond_to do |format|
      format.html { render html: @cache_this }
      format.json { render json: @cache_this }
    end
  end

  def expire_accept
    if params.key?(:format)
      expire_action action: "accept", format: params[:format]
    elsif !request.format.html?
      expire_action action: "accept", format: request.format.to_sym
    else
      expire_action action: "accept"
    end

    head :ok
  end

  protected
    def cache_path_protected_method
      ["controller", params[:id]].compact.join("-")
    end

    if ActionPack::VERSION::STRING < "4.1"
      def render(options)
        if options.key?(:plain)
          super({ text: options.delete(:plain) }.merge(options))
          response.content_type = "text/plain"
        elsif options.key?(:html)
          super({ text: options.delete(:html) }.merge(options))
          response.content_type = "text/html"
        else
          super
        end
      end
    end
end

class MockTime < Time
  # Let Time spicy to assure that Time.now != Time.now
  def to_f
    super + rand
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
    Object.new.instance_eval <<-EVAL
      def path; "#{@mock_path}" end
      def format; "all" end
      def parameters; { format: nil }; end
      self
    EVAL
  end
end

class ActionCacheTest < ActionController::TestCase
  tests ActionCachingTestController

  def setup
    super

    @routes = ActionDispatch::Routing::RouteSet.new

    @request.host = "hostname.com"
    FileUtils.mkdir_p(FILE_STORE_PATH)
    @path_class = ActionController::Caching::Actions::ActionCachePath
    @mock_controller = ActionCachingMockController.new
  end

  def teardown
    super
    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
  end

  def test_simple_action_cache_with_http_head
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
    end

    head :index
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?("hostname.com/action_caching_test")

    head :index
    assert_response :success
    assert_equal cached_time, @response.body
  end

  def test_simple_action_cache
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
    end

    get :index
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?("hostname.com/action_caching_test")

    get :index
    assert_response :success
    assert_equal cached_time, @response.body
  end

  def test_simple_action_not_cached
    draw do
      get "/action_caching_test/destroy", to: "action_caching_test#destroy"
    end

    get :destroy
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert !fragment_exist?("hostname.com/action_caching_test/destroy")

    get :destroy
    assert_response :success
    assert_not_equal cached_time, @response.body
  end

  def test_action_cache_with_layout
    draw do
      get "/action_caching_test/with_layout", to: "action_caching_test#with_layout"
    end

    get :with_layout
    assert_response :success
    cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    assert fragment_exist?("hostname.com/action_caching_test/with_layout")

    get :with_layout
    assert_response :success
    assert_not_equal cached_time, @response.body
    assert_equal @response.body, read_fragment("hostname.com/action_caching_test/with_layout")
  end

  def test_action_cache_with_layout_and_layout_cache_false
    draw do
      get "/action_caching_test/layout_false", to: "action_caching_test#layout_false"
    end

    get :layout_false, params: { title: "Request 1" }
    assert_response :success
    cached_time = content_to_cache
    assert_equal "<title>Request 1</title>\n#{cached_time}", @response.body
    assert_equal cached_time, read_fragment("hostname.com/action_caching_test/layout_false")

    get :layout_false, params: { title: "Request 2" }
    assert_response :success
    assert_equal "<title>Request 2</title>\n#{cached_time}", @response.body
    assert_equal cached_time, read_fragment("hostname.com/action_caching_test/layout_false")
  end

  def test_action_cache_with_layout_and_layout_cache_false_via_proc
    draw do
      get "/action_caching_test/with_layout_proc_param", to: "action_caching_test#with_layout_proc_param"
    end

    get :with_layout_proc_param, params: { title: "Request 1", layout: "false" }
    assert_response :success
    cached_time = content_to_cache
    assert_equal "<title>Request 1</title>\n#{cached_time}", @response.body
    assert_equal cached_time, read_fragment("hostname.com/action_caching_test/with_layout_proc_param")

    get :with_layout_proc_param, params: { title: "Request 2", layout: "false" }
    assert_response :success
    assert_equal "<title>Request 2</title>\n#{cached_time}", @response.body
    assert_equal cached_time, read_fragment("hostname.com/action_caching_test/with_layout_proc_param")
  end

  def test_action_cache_with_layout_and_layout_cache_true_via_proc
    draw do
      get "/action_caching_test/with_layout_proc_param", to: "action_caching_test#with_layout_proc_param"
    end

    get :with_layout_proc_param, params: { title: "Request 1", layout: "true" }
    assert_response :success
    cached_time = content_to_cache
    assert_equal "<title>Request 1</title>\n#{cached_time}", @response.body
    assert_equal "<title>Request 1</title>\n#{cached_time}", read_fragment("hostname.com/action_caching_test/with_layout_proc_param")

    get :with_layout_proc_param, params: { title: "Request 2", layout: "true" }
    assert_response :success
    assert_equal "<title>Request 1</title>\n#{cached_time}", @response.body
    assert_equal "<title>Request 1</title>\n#{cached_time}", read_fragment("hostname.com/action_caching_test/with_layout_proc_param")
  end

  def test_action_cache_conditional_options
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
    end

    @request.accept = "application/json"
    get :index
    assert_response :success
    assert !fragment_exist?("hostname.com/action_caching_test")
  end

  def test_action_cache_with_format_and_http_param
    draw do
      get "/action_caching_test/with_format_and_http_param", to: "action_caching_test#with_format_and_http_param"
    end

    get :with_format_and_http_param, format: "json"
    assert_response :success
    assert !fragment_exist?("hostname.com/action_caching_test/with_format_and_http_param.json?key=value.json")
    assert fragment_exist?("hostname.com/action_caching_test/with_format_and_http_param.json?key=value")
  end

  def test_action_cache_with_symbol_format
    draw do
      get "/action_caching_test/with_symbol_format", to: "action_caching_test#with_symbol_format"
    end

    get :with_symbol_format
    assert_response :success
    assert !fragment_exist?("test.host/action_caching_test/with_symbol_format")
    assert fragment_exist?("test.host/action_caching_test/with_symbol_format.json")
  end

  def test_action_cache_not_url_cache_path
    draw do
      get "/action_caching_test/not_url_cache_path", to: "action_caching_test#not_url_cache_path"
    end

    get :not_url_cache_path
    assert_response :success
    assert !fragment_exist?("test.host/action_caching_test/not_url_cache_path")
    assert fragment_exist?("not_url_cache_path_key")
  end

  def test_action_cache_with_store_options
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
    end

    MockTime.expects(:now).returns(12345).once
    @controller.expects(:read_fragment).with("hostname.com/action_caching_test", expires_in: 1.hour).once
    @controller.expects(:write_fragment).with("hostname.com/action_caching_test", "12345.0", expires_in: 1.hour).once
    get :index
    assert_response :success
  end

  def test_action_cache_with_custom_cache_path
    draw do
      get "/action_caching_test/show", to: "action_caching_test#show"
    end

    get :show
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?("test.host/custom/show")

    get :show
    assert_response :success
    assert_equal cached_time, @response.body
  end

  def test_action_cache_with_custom_cache_path_in_block
    draw do
      get "/action_caching_test/edit(/:id)", to: "action_caching_test#edit"
    end

    get :edit
    assert_response :success
    assert fragment_exist?("test.host/edit")

    get :edit, params: { id: 1 }
    assert_response :success
    assert fragment_exist?("test.host/1;edit")
  end

  def test_action_cache_with_custom_cache_path_with_custom_object
    draw do
      get "/action_caching_test/custom_cache_path(/:id)", to: "action_caching_test#custom_cache_path"
    end

    get :custom_cache_path
    assert_response :success
    assert fragment_exist?("controller")

    get :custom_cache_path, params: { id: 1 }
    assert_response :success
    assert fragment_exist?("controller-1")
  end

  def test_action_cache_with_symbol_cache_path
    draw do
      get "/action_caching_test/symbol_cache_path(/:id)", to: "action_caching_test#symbol_cache_path"
    end

    get :symbol_cache_path
    assert_response :success
    assert fragment_exist?("controller")

    get :symbol_cache_path, params: { id: 1 }
    assert_response :success
    assert fragment_exist?("controller-1")
  end

  def test_cache_expiration
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
      get "/action_caching_test/expire", to: "action_caching_test#expire"
    end

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
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
      get "/action_caching_test/expire", to: "action_caching_test#expire"
    end

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
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
      get "/action_caching_test/expire_with_url_string", to: "action_caching_test#expire_with_url_string"
    end

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
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
    end

    @request.host = "jamis.hostname.com"
    get :index
    assert_response :success
    jamis_cache = content_to_cache

    @request.host = "david.hostname.com"
    get :index
    assert_response :success
    david_cache = content_to_cache
    assert_not_equal jamis_cache, @response.body

    @request.host = "jamis.hostname.com"
    get :index
    assert_response :success
    assert_equal jamis_cache, @response.body

    @request.host = "david.hostname.com"
    get :index
    assert_response :success
    assert_equal david_cache, @response.body
  end

  def test_redirect_is_not_cached
    draw do
      get "/action_caching_test", to: "action_caching_test#index"
      get "/action_caching_test/redirected", to: "action_caching_test#redirected"
    end

    get :redirected
    assert_response :redirect
    get :redirected
    assert_response :redirect
  end

  def test_forbidden_is_not_cached
    draw do
      get "/action_caching_test/forbidden", to: "action_caching_test#forbidden"
    end

    get :forbidden
    assert_response :forbidden
    get :forbidden
    assert_response :forbidden
  end

  def test_xml_version_of_resource_is_treated_as_different_cache
    draw do
      get "/action_caching_test/index", to: "action_caching_test#index"
      get "/action_caching_test/expire_xml", to: "action_caching_test#expire_xml"
    end

    get :index, format: "xml"
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?("hostname.com/action_caching_test/index.xml")

    get :index, format: "xml"
    assert_response :success
    assert_equal cached_time, @response.body
    assert_equal "application/xml", @response.content_type

    get :expire_xml
    assert_response :success

    get :index, format: "xml"
    assert_response :success
    assert_not_equal cached_time, @response.body
  end

  def test_correct_content_type_is_returned_for_cache_hit
    draw do
      get "/action_caching_test/index/:id", to: "action_caching_test#index"
    end

    # run it twice to cache it the first time
    get :index, params: { id: "content-type" }, format: "xml"
    get :index, params: { id: "content-type" }, format: "xml"
    assert_response :success
    assert_equal "application/xml", @response.content_type
  end

  def test_correct_content_type_is_returned_for_cache_hit_on_action_with_string_key
    draw do
      get "/action_caching_test/show", to: "action_caching_test#show"
    end

    # run it twice to cache it the first time
    get :show, format: "xml"
    get :show, format: "xml"
    assert_response :success
    assert_equal "application/xml", @response.content_type
  end

  def test_correct_content_type_is_returned_for_cache_hit_on_action_with_string_key_from_proc
    draw do
      get "/action_caching_test/edit/:id", to: "action_caching_test#edit"
    end

    # run it twice to cache it the first time
    get :edit, params: { id: 1 }, format: "xml"
    get :edit, params: { id: 1 }, format: "xml"
    assert_response :success
    assert_equal "application/xml", @response.content_type
  end

  def test_empty_path_is_normalized
    @mock_controller.mock_url_for = "http://example.org/"
    @mock_controller.mock_path    = "/"

    assert_equal "example.org/index", @path_class.new(@mock_controller, {}).path
  end

  def test_file_extensions
    draw do
      get "/action_caching_test/index/*id", to: "action_caching_test#index", format: false
    end

    get :index, params: { id: "kitten.jpg" }
    get :index, params: { id: "kitten.jpg" }

    assert_response :success
  end

  if defined? ActiveRecord
    def test_record_not_found_returns_404_for_multiple_requests
      draw do
        get "/action_caching_test/record_not_found", to: "action_caching_test#record_not_found"
      end

      get :record_not_found
      assert_response 404
      get :record_not_found
      assert_response 404
    end
  end

  def test_four_oh_four_returns_404_for_multiple_requests
    draw do
      get "/action_caching_test/four_oh_four", to: "action_caching_test#four_oh_four"
    end

    get :four_oh_four
    assert_response 404
    get :four_oh_four
    assert_response 404
  end

  def test_four_oh_four_renders_content
    draw do
      get "/action_caching_test/four_oh_four", to: "action_caching_test#four_oh_four"
    end

    get :four_oh_four
    assert_equal "404'd!", @response.body
  end

  def test_simple_runtime_error_returns_500_for_multiple_requests
    draw do
      get "/action_caching_test/simple_runtime_error", to: "action_caching_test#simple_runtime_error"
    end

    get :simple_runtime_error
    assert_response 500
    get :simple_runtime_error
    assert_response 500
  end

  def test_action_caching_plus_streaming
    draw do
      get "/action_caching_test/streaming", to: "action_caching_test#streaming"
    end

    get :streaming
    assert_response :success
    assert_match(/streaming/, @response.body)
    assert fragment_exist?("hostname.com/action_caching_test/streaming")
  end

  def test_invalid_format_returns_not_acceptable
    draw do
      get "/action_caching_test/invalid", to: "action_caching_test#invalid"
    end

    get :invalid, format: "json"
    assert_response :success
    cached_time = content_to_cache
    assert_equal cached_time, @response.body

    assert fragment_exist?("hostname.com/action_caching_test/invalid.json")

    get :invalid, format: "json"
    assert_response :success
    assert_equal cached_time, @response.body

    get :invalid, format: "xml"
    assert_response :not_acceptable

    get :invalid, format: "\xC3\x83"
    assert_response :not_acceptable
  end

  def test_format_from_accept_header
    draw do
      get "/action_caching_test/accept", to: "action_caching_test#accept"
      get "/action_caching_test/accept/expire", to: "action_caching_test#expire_accept"
    end

    # Cache the JSON format
    get_json :accept
    json_cached_time = content_to_cache
    assert_cached json_cached_time, "application/json"

    # Check that the JSON format is cached
    get_json :accept
    assert_cached json_cached_time, "application/json"

    # Cache the HTML format
    get_html :accept
    html_cached_time = content_to_cache
    assert_cached html_cached_time

    # Check that it's not the JSON format
    assert_not_equal json_cached_time, @response.body

    # Check that the HTML format is cached
    get_html :accept
    assert_cached html_cached_time

    # Check that the JSON format is still cached
    get_json :accept
    assert_cached json_cached_time, "application/json"

    # Expire the JSON format
    get_json :expire_accept
    assert_response :success

    # Check that the HTML format is still cached
    get_html :accept
    assert_cached html_cached_time

    # Check the JSON format was expired
    get_json :accept
    new_json_cached_time = content_to_cache
    assert_cached new_json_cached_time, "application/json"
    assert_not_equal json_cached_time, @response.body

    # Expire the HTML format
    get_html :expire_accept
    assert_response :success

    # Check that the JSON format is still cached
    get_json :accept
    assert_cached new_json_cached_time, "application/json"

    # Check the HTML format was expired
    get_html :accept
    new_html_cached_time = content_to_cache
    assert_cached new_html_cached_time
    assert_not_equal html_cached_time, @response.body
  end

  def test_explicit_html_format_is_used_for_fragment_path
    draw do
      get "/action_caching_test/accept", to: "action_caching_test#accept"
      get "/action_caching_test/accept/expire", to: "action_caching_test#expire_accept"
    end

    get :accept, format: "html"
    cached_time = content_to_cache
    assert_cached cached_time

    assert fragment_exist?("hostname.com/action_caching_test/accept.html")

    get :accept, format: "html"
    cached_time = content_to_cache
    assert_cached cached_time

    get :expire_accept, format: "html"
    assert_response :success

    assert !fragment_exist?("hostname.com/action_caching_test/accept.html")

    get :accept, format: "html"
    assert_not_cached cached_time
  end

  def test_lambda_arity_with_cache_path
    draw do
      get "/action_caching_test/not_url_cache_path_no_args", to: "action_caching_test#not_url_cache_path_no_args"
    end

    get :not_url_cache_path_no_args
    assert_response :success
    assert !fragment_exist?("test.host/action_caching_test/not_url_cache_path_no_args")
    assert fragment_exist?("not_url_cache_path_no_args_key")
  end

  def test_lambda_arity_with_layout
    draw do
      get "/action_caching_test/with_layout_proc_param_no_args", to: "action_caching_test#with_layout_proc_param_no_args"
    end

    get :with_layout_proc_param_no_args, params: { title: "Request 1", layout: "false" }
    assert_response :success
    cached_time = content_to_cache
    assert_equal "<title>Request 1</title>\n#{cached_time}", @response.body
    assert_equal cached_time, read_fragment("hostname.com/action_caching_test/with_layout_proc_param_no_args")

    get :with_layout_proc_param_no_args, params: { title: "Request 2", layout: "false" }
    assert_response :success
    assert_equal "<title>Request 2</title>\n#{cached_time}", @response.body
    assert_equal cached_time, read_fragment("hostname.com/action_caching_test/with_layout_proc_param_no_args")
  end

  private
    def get_html(*args)
      @request.accept = "text/html"
      get(*args)
    end

    def get_json(*args)
      @request.accept = "application/json"
      get(*args)
    end

    def assert_cached(cache_time, content_type = "text/html")
      assert_response :success
      assert_equal cache_time, @response.body
      assert_equal content_type, @response.content_type
    end

    def assert_not_cached(cache_time, content_type = "text/html")
      assert_response :success
      assert_not_equal cache_time, @response.body
      assert_equal content_type, @response.content_type
    end

    def content_to_cache
      @controller.instance_variable_get(:@cache_this)
    end

    def fragment_exist?(path)
      @controller.fragment_exist?(path)
    end

    def read_fragment(path)
      @controller.read_fragment(path)
    end

    def draw(&block)
      @routes = ActionDispatch::Routing::RouteSet.new
      @routes.draw(&block)
      @controller.extend(@routes.url_helpers)
    end

    if ActionPack::VERSION::STRING < "5.0"
      def get(action, options = {})
        format = options.slice(:format)
        params = options[:params] || {}
        session = options[:session] || {}
        flash = options[:flash] || {}

        super(action, params.merge(format), session, flash)
      end
    end
end
