require 'test/unit'
require 'cgi'

require 'rubygems'

require 'action_controller'
require 'action_controller/test_process'



require File.dirname(__FILE__)+"/../lib/cas_auth"
require File.dirname(__FILE__)+"/../lib/cas_logger"

# Re-raise errors caught by the controller.
class CasProtectedTestController < ActionController::Base
  before_filter CAS::Filter
  def rescue_action(e) raise e end
  def dummy; render(:nothing => true) end
  def true; render(:nothing => true) end
end

ActionController::Routing::Routes.draw do |map|
  # dummy action to make ActionController happy
  map.connect '', :controller => 'cas_protected_test', :action => 'dummy'
  map.connect ':controller/:action'
end

class CasTest < Test::Unit::TestCase

  def setup
    # you need to create this file and set up CAS::Filter.cas_base_url and other values as per your local CAS installation
    load 'local_test_settings.rb'
  
    @controller = CasProtectedTestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    f = File.open(File.dirname(__FILE__)+"/cas_test.log", File::WRONLY | File::APPEND | File::CREAT)
    CAS::Filter.logger = CAS::Logger.new(f)
    CAS::Filter.logger.formatter = CAS::Logger::Formatter.new
    CAS::Filter.logger.level = Logger::DEBUG
    
    @controller.request = @request
    @controller.response = @response
    @controller.session = {}
    @controller.params = {}
    
    @fake_service_url = "http://testapp.test.com"
    @fake_service_url_with_params = "http://testapp.test.com?foo[bar]=hello&testing=blahblah&some_encoded_uri=http%3A%2F%2Fwww.google.com%2Fsearch%3Fq%3DRubyCAS-Client%26ie%3Dutf-8%26oe%3Dutf-8%26rls%3Dorg.mozilla%3Aen-US%3Aofficial%26client%3Dfirefox-a&anotherValue[1]=hurray"
  end
  
  def test_redirect_url
    CAS::Filter.login_url = "https://test.com/cas/login"
    
    CAS::Filter.service_url = @fake_service_url
    assert_equal "https://test.com/cas/login?service=#{CGI.escape(@fake_service_url)}", CAS::Filter.redirect_url(@controller)
    
    CAS::Filter.service_url = @fake_service_url_with_params
    assert_equal "https://test.com/cas/login?service=#{CGI.escape(@fake_service_url_with_params)}", CAS::Filter.redirect_url(@controller)
    
    # misc params in the current request shouldn't have any effect on redirect_url when we have an explicit service_url
    @controller.params = {:some => "value", :another => "value2"}
    CAS::Filter.service_url = @fake_service_url_with_params
    assert_equal "https://test.com/cas/login?service=#{CGI.escape(@fake_service_url_with_params)}", CAS::Filter.redirect_url(@controller)
    
    # make sure that misc parms are retained correctly when we guess the service url
    @controller.params = {'some[foo]' => "val&amp;ue"}
    CAS::Filter.service_url = nil
    # ActionController seems to default to 'localhost' as the server name... I'm not sure how to change this
    expected_service_url = "http://localhost/?some[foo]=val&amp;ue" # NOTE: need trailing slash in url, otherwise test fails
    assert_equal "https://test.com/cas/login?service=#{CGI.escape(expected_service_url)}", CAS::Filter.redirect_url(@controller)
    
    # service param should be used when Filter.service_url is nil
    CAS::Filter.service_url = nil
    @controller.params = {:service => "http://new.service.com/cas"}
    assert_equal "https://test.com/cas/login?service=#{CGI.escape('http://new.service.com/cas')}", CAS::Filter.redirect_url(@controller)
    
    # Filter.service_url should override service param
    CAS::Filter.service_url = @fake_service_url
    @controller.params = {:service => "http://new.service.com/cas"}
    assert_equal "https://test.com/cas/login?service=#{CGI.escape(@fake_service_url)}", CAS::Filter.redirect_url(@controller)
    
    # ticket param should be removed if present in service param
    CAS::Filter.service_url = nil
    @controller.params = {:service => "http://new.service.com/cas?ticket=test123&another[foo]=parameter&more=good"}
    assert_equal "https://test.com/cas/login?service=#{CGI.escape('http://new.service.com/cas?another[foo]=parameter&more=good')}", CAS::Filter.redirect_url(@controller)
  end

  def test_create_logout_url
    CAS::Filter.login_url = "https://test.com/cas/login"
    CAS::Filter.service_url = @fake_service_url_with_params
    
    # guessed logout_url
    CAS::Filter.logout_url = nil
    CAS::Filter.create_logout_url
    
    assert_equal "https://test.com/cas/logout?service=#{CGI.escape(@fake_service_url_with_params)}", CAS::Filter.logout_url(@controller)
    
    # explicitly set logout_url
    CAS::Filter.logout_url = "https://test2.com/cas/logout"
    CAS::Filter.create_logout_url
    
    assert_equal "https://test2.com/cas/logout?service=#{CGI.escape(@fake_service_url_with_params)}", CAS::Filter.logout_url(@controller)
  end
  
  def test_cas_base_url
    base = "https://test.com/cas"
    CAS::Filter.cas_base_url = base
    
    assert_equal "#{base}/login", CAS::Filter.login_url
    assert_equal "#{base}/proxyValidate", CAS::Filter.validate_url
    assert_equal "#{base}/proxy", CAS::Filter.proxy_url
  end
  
  def test_fake_filter
    # this test is kind of pointless...
    
    CAS::Filter.fake = "mzukowski"
    
    assert CAS::Filter.filter(@controller)
    assert "mzukowski", @controller.session[CAS::Filter.session_username]
  end
  
  # this test assumes that you have a valid CAS server, and that you have $valid_username and $valid_password
  # configured in your local_test_settings.rb
#  def test_fresh_login_with_explicit_service
#    CAS::Filter.fake = nil # make sure fake filter is disabled (might have been enabled for the class in earlier test)
#    
#    raise "Can't run this test because $valid_username is not set." unless $valid_username
#    raise "Can't run this test because $valid_password is not set." unless $valid_password
#    raise "Can't run this test because CAS::Filter.login_url is not set." unless CAS::Filter.login_url
#    
#    CAS::Filter.service_url = @fake_service_url_with_params
#    
#    get CAS::Filter.filter(@controller), nil,  nil
#    assert_redirected_to CAS::Filter.login_url+"?service="+CGI.escape(@fake_service_url_with_params)
#    
#    url = URI.parse(CAS::Filter.login_url)
#    
#    http = Net::HTTP.new(url.host, url.port)
#    http.use_ssl = true
#    
#    res = http.request_get(url.to_s)
#    /name="lt" value="(.*?)"/ =~ res.body
#    lt = $1
#    
#    
#    req = Net::HTTP::Post.new(url.path)
#    req.set_form_data('service' => CGI.escape(@fake_service_url_with_params), 'username'=> $valid_username, 
#                        'password'=> $valid_password, 'submit' => 'LOGIN', '_currentStateId' => 'viewLoginForm',
#                        'lt' => lt, '_eventId' => 'submit')
#    
#    res = http.start {|http| http.request(req) }
#    puts res.to_hash.inspect
#    res = http.request_get(res.to_hash['location'])
#
#    # arghhhhh!!!!!!!!!!!!!!!!!!!
#  end
end
