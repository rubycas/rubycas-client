require File.dirname(__FILE__) + '/test_helper.rb'

class CASClientTest < Test::Unit::TestCase

  def setup
    @cas_success = %{
      <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
        <cas:authenticationSuccess>
          <cas:user>mzukowski</cas:user>
          <cas:proxyGrantingTicket>PGTIOU-84678-8a9d</cas:proxyGrantingTicket>
          <cas:proxies>
            <cas:proxy>https://proxy2/pgtUrl</cas:proxy>
            <cas:proxy>https://proxy1/pgtUrl</cas:proxy>
          </cas:proxies>
          <test:email>mzukowski@example.foo</test:email>
          <misc>Matt Zukowski</misc>
        </cas:authenticationSuccess>
      </cas:serviceResponse>
    }
    
    @cas_failure = %{
      <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
        <cas:authenticationFailure code="INVALID_TICKET">
            Ticket ST-1856339-aA5Yuvrxzpv8Tau1cYQ7 not recognized
        </cas:authenticationFailure>
      </cas:serviceResponse>
    }
  end
  
  def test_truth
    assert true
  end
end
