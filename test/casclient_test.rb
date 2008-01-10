require File.dirname(__FILE__) + '/test_helper.rb'

###
# These tests require a working CAS server!
###

$LOGIN_URL = 'https://localhost:6543/cas/login'
$VALIDATE_URL = 'https://localhost:6543/cas/proxyValidate'

puts "Enter a valid username for #{$LOGIN_URL.inspect}:"
$USERNAME = $stdin.gets.strip
puts "Enter a valid password for #{$USERNAME.inspect}:"
$PASSWORD = $stdin.gets.strip

class CASClientTest < Test::Unit::TestCase

  def setup
    @login_url = $LOGIN_URL
    @validate_url = $VALIDATE_URL
    
    @valid_credentials = {:username => $USERNAME, :password => $PASSWORD}
    
    @client = CASClient::Client.new(
      :login_url => @login_url, :validate_url => @validate_url
    )
  end
  
  def test_validate_bad_service_ticket
    st = CASClient::ServiceTicket.new('TESTING-BAD-TICKET', 'http://test.foo')
    @client.validate_service_ticket(st)
    
    assert st.response.is_failure?
    assert_equal 'INVALID_TICKET', st.response.failure_code
  end
  
  def test_request_login_ticket
    lt = @client.request_login_ticket
    
    assert !lt.blank?
    assert lt =~ /LT-.+/
  end

  def test_successful_login_to_service
    credentials = @valid_credentials
    lr = @client.login_to_service(credentials, 'http://test.foo?foo=bar')
    
    assert !lr.ticket.blank?
    assert !lr.tgt.blank?
    assert lr.service_redirect_url =~ /^http:\/\/test.foo\?foo=bar&ticket=/
  end
  
  def test_login_to_service_with_bad_credentials
    lr = @client.login_to_service({:username => "BAD_USERNAME", :password => "BAD_PASSWORD"}, 'http://test.foo?foo=bar')
    
    assert !lr.is_success?
    assert lr.is_failure?
    assert lr.failure_message =~ /username/ 
  end
end
