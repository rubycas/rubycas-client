require File.dirname(__FILE__) + '/test_helper.rb'

class CASClientTest < Test::Unit::TestCase

  def setup
    @cas1_success = "yes\nmzukowski\n"
    @cas1_failure = "no\n\n"
    
    @cas2_success = %{
      <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
        <cas:authenticationSuccess>
          <cas:user>mzukowski</cas:user>
          <cas:proxyGrantingTicket>PGTIOU-84678-8a9d</cas:proxyGrantingTicket>
          <cas:proxies>
            <cas:proxy>https://proxy2/pgtUrl</cas:proxy>
            <cas:proxy>https://proxy1/pgtUrl</cas:proxy>
          </cas:proxies>
          <foo:email>mzukowski@example.foo</foo:email>
          <full-name>Matt Zukowski</full-name>
        </cas:authenticationSuccess>
      </cas:serviceResponse>
    }
    
    @cas2_success_minimal = %{
      <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
        <cas:authenticationSuccess>
          <cas:user>mzukowski</cas:user>
        </cas:authenticationSuccess>
      </cas:serviceResponse>
    }
    
    @cas2_failure = %{
      <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
        <cas:authenticationFailure code="INVALID_TICKET">
            Ticket ST-1856339-aA5Yuvrxzpv8Tau1cYQ7 not recognized
        </cas:authenticationFailure>
      </cas:serviceResponse>
    }
    
    @client = CASClient::Client.new(
      :login_url => 'https://localhost/cas/login', 
      :validate_url => 'https://localhost/cas/serviceValidate'
    )
  end
  
  def test_parse_cas2_success_response
    r = CASClient::Response.new(@cas2_success)
    
    assert_equal 2.0, r.protocol
    assert r.is_success?
    assert !r.is_failure?
    assert_equal 'mzukowski', r.user
    assert_equal 'Matt Zukowski', r.extra_attributes['full_name']
    assert_equal ['https://proxy2/pgtUrl', 'https://proxy1/pgtUrl'], r.proxies
    assert_equal 'PGTIOU-84678-8a9d', r.pgt
    
    r = CASClient::Response.new(@cas2_success_minimal)
    
    assert_equal 2.0, r.protocol
    assert r.is_success?
    assert !r.is_failure?
    assert_equal 'mzukowski', r.user
    assert_nil r.extra_attributes['full_name']
    assert_nil r.proxies
    assert_nil r.pgt
  end
  
  def test_parse_cas2_failure_response
    r = CASClient::Response.new(@cas2_failure)
    
    assert_equal 2.0, r.protocol
    assert !r.is_success?
    assert r.is_failure?
    assert_equal 'INVALID_TICKET', r.failure_code
    assert_equal 'Ticket ST-1856339-aA5Yuvrxzpv8Tau1cYQ7 not recognized', r.failure_message
    assert_nil r.user
    assert_nil r.extra_attributes
    assert_nil r.proxies
    assert_nil r.pgt
  end
  
  def test_parse_cas1_success_response
    r = CASClient::Response.new(@cas1_success)
    
    assert_equal 1.0, r.protocol
    assert r.is_success?
    assert !r.is_failure?
    assert_equal 'mzukowski', r.user
  end
  
  def test_parse_cas1_fail_response
    r = CASClient::Response.new(@cas1_failure)
    
    assert_equal 1.0, r.protocol
    assert !r.is_success?
    assert r.is_failure?
  end
end
