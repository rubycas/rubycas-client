require 'teststrap'
require 'casclient/frameworks/rails/filter'
require 'action_controller'

context CASClient::Frameworks::Rails::Filter do
  
  helper(:controller_with_session) do |session, request|
    controller = Object.new
    stub(controller).session {session}
    stub(controller).request {request}
    stub(controller).url_for {"bogusurl"}
    stub(controller).params {{:ticket => "bogusticket", :renew => false}}
    controller
  end
    
  setup do
    CASClient::Frameworks::Rails::Filter.configure(
      :cas_base_url => 'http://test.local/',
      :logger => stub!
    )
  end
  
  context "new service ticket successfully" do
     should("return successfully from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}
      
      pgt = CASClient::ProxyGrantingTicket.new(
      "PGT-1308586001r9573FAD5A8C62E134A4AA93273F226BD3F0C3A983DCCCD176",
      "PGTIOU-1308586001r29DC1F852C95930FE6694C1EFC64232A3359798893BC0B")
      
      raw_text = "<cas:serviceResponse xmlns:cas=\"http://www.yale.edu/tp/cas\">
                    <cas:authenticationSuccess>
                      <cas:user>rich.yarger@vibes.com</cas:user>
                      <cas:proxyGrantingTicket>PGTIOU-1308586001r29DC1F852C95930FE6694C1EFC64232A3359798893BC0B</cas:proxyGrantingTicket>
                    </cas:authenticationSuccess>
                  </cas:serviceResponse>"
      response = CASClient::ValidationResponse.new(raw_text)
      
      any_instance_of(CASClient::Client, :request_cas_response => response)
      any_instance_of(CASClient::Client, :retrieve_proxy_granting_ticket => pgt)
      
      controller = controller_with_session(topic,mock_request)
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.equals(true)
  end
  
  context "new service ticket with invalid service ticket" do
     should("return failure from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}
      
      raw_text = "<cas:serviceResponse xmlns:cas=\"http://www.yale.edu/tp/cas\">
                    <cas:authenticationFailure>Some Error Text</cas:authenticationFailure>
                  </cas:serviceResponse>"
      response = CASClient::ValidationResponse.new(raw_text)
      
      any_instance_of(CASClient::Client, :request_cas_response => response)
      stub(CASClient::Frameworks::Rails::Filter).unauthorized!{"bogusresponse"}
      
      controller = controller_with_session(topic,mock_request)
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.equals(false)
  end
  
  context "no new service ticket but with last service ticket" do
     should("return failure from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}

      stub(CASClient::Frameworks::Rails::Filter).unauthorized!{"bogusresponse"}
      
      controller = controller_with_session(topic,mock_request)
      stub(controller).params {{}}
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.equals(false)
  end
  
  context "no new service ticket sent through gateway, gatewaying off" do
     should("return failure from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}

      stub(CASClient::Frameworks::Rails::Filter).unauthorized!{"bogusresponse"}
      
      CASClient::Frameworks::Rails::Filter.config[:use_gatewaying] = false 
      controller = controller_with_session(topic,mock_request)
      controller.session[:cas_sent_to_gateway] = true
      stub(controller).params {{}}
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.equals(false)
  end
  
  context "no new service ticket sent through gateway, gatewaying on" do
     should("return failure from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}
 
      CASClient::Frameworks::Rails::Filter.config[:use_gatewaying] = true 
      controller = controller_with_session(topic,mock_request)
      controller.session[:cas_sent_to_gateway] = true
      stub(controller).params {{}}
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.equals(true)
  end
  
  context "new service ticket with no PGT" do
     should("return failure from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}
      
      raw_text = "<cas:serviceResponse xmlns:cas=\"http://www.yale.edu/tp/cas\">
                    <cas:authenticationSuccess>
                      <cas:user>rich.yarger@vibes.com</cas:user>
                      <cas:proxyGrantingTicket>PGTIOU-1308586001r29DC1F852C95930FE6694C1EFC64232A3359798893BC0B</cas:proxyGrantingTicket>
                    </cas:authenticationSuccess>
                  </cas:serviceResponse>"
      response = CASClient::ValidationResponse.new(raw_text)
      
      any_instance_of(CASClient::Client, :request_cas_response => response)
      any_instance_of(CASClient::Client, :retrieve_proxy_granting_ticket => lambda{raise CASClient::CASException})
      
      controller = controller_with_session(topic,mock_request)
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.raises(CASClient::CASException)
  end
  
  context "new service ticket, but cannot connect to CASServer" do
     should("return failure from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}
      
      any_instance_of(CASClient::Client, :request_cas_response => lambda{raise "Some exception"})
      
      controller = controller_with_session(topic,mock_request)
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.raises(RuntimeError)
  end
  
  context "reuse service ticket successfully" do
     should("return successfully from filter") do
      setup { Hash.new }
      mock_request = ActionController::Request.new({})
      mock(mock_request).post? {true}
      
      pgt = CASClient::ProxyGrantingTicket.new(
      "PGT-1308586001r9573FAD5A8C62E134A4AA93273F226BD3F0C3A983DCCCD176",
      "PGTIOU-1308586001r29DC1F852C95930FE6694C1EFC64232A3359798893BC0B")
      
      raw_text = "<cas:serviceResponse xmlns:cas=\"http://www.yale.edu/tp/cas\">
                    <cas:authenticationSuccess>
                      <cas:user>rich.yarger@vibes.com</cas:user>
                      <cas:proxyGrantingTicket>PGTIOU-1308586001r29DC1F852C95930FE6694C1EFC64232A3359798893BC0B</cas:proxyGrantingTicket>
                    </cas:authenticationSuccess>
                  </cas:serviceResponse>"
      response = CASClient::ValidationResponse.new(raw_text)
      
      any_instance_of(CASClient::Client, :request_cas_response => response)
      any_instance_of(CASClient::Client, :retrieve_proxy_granting_ticket => pgt)
      
      topic[:cas_last_valid_ticket] = CASClient::ServiceTicket.new("bogusticket",'bogusurl')
      controller = controller_with_session(topic,mock_request)
      CASClient::Frameworks::Rails::Filter.filter(controller)
     end.equals(true)
  end
  
  context "fake user without attributes" do
    setup { CASClient::Frameworks::Rails::Filter.fake('tester@test.com') }
    should 'set the session user on #filter' do
      setup { Hash.new }
      CASClient::Frameworks::Rails::Filter.filter(controller_with_session(topic,nil))
      topic
    end.equals :cas_user => 'tester@test.com', :casfilteruser => 'tester@test.com'
  end
  
  context "fake user with attributes" do
    setup { CASClient::Frameworks::Rails::Filter.fake('tester@test.com', {:test => 'stuff', :this => 'that'}) }
    should 'set the session user and attributes on #filter' do
      setup { Hash.new }
      CASClient::Frameworks::Rails::Filter.filter(controller_with_session(topic,nil))
      topic
    end.equals :cas_user => 'tester@test.com', :casfilteruser => 'tester@test.com', :cas_extra_attributes => {:test => 'stuff', :this => 'that' }
  end
end
