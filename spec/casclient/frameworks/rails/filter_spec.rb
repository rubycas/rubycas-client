require 'spec_helper'
require 'action_controller'
require 'casclient/frameworks/rails/filter'

describe CASClient::Frameworks::Rails::Filter do

  before(:each) do
    CASClient::Frameworks::Rails::Filter.configure(
      :cas_base_url => 'http://test.local/',
      :logger => double("Logger")
    )
  end

  describe "#fake" do
    subject { Hash.new }
    context "faking user without attributes" do
      before { CASClient::Frameworks::Rails::Filter.fake('tester@test.com') }
      it 'should set the session user' do
        CASClient::Frameworks::Rails::Filter.filter(mock_controller_with_session(nil, subject))
        subject.should eq({:cas_user => 'tester@test.com', :casfilteruser => 'tester@test.com'})
      end
      after { CASClient::Frameworks::Rails::Filter.fake(nil,nil) }
    end

    context "faking user with attributes" do
      before { CASClient::Frameworks::Rails::Filter.fake('tester@test.com', {:test => 'stuff', :this => 'that'}) }
      it 'should set the session user and attributes' do
        CASClient::Frameworks::Rails::Filter.filter(mock_controller_with_session(nil, subject))
        subject.should eq({ :cas_user => 'tester@test.com', :casfilteruser => 'tester@test.com', :cas_extra_attributes => {:test => 'stuff', :this => 'that' }})
      end
      after { CASClient::Frameworks::Rails::Filter.fake(nil,nil) }
    end
  end

  context "new valid service ticket" do
     it "should return successfully from filter" do

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

      CASClient::Client.any_instance.stub(:request_cas_response).and_return(response)
      CASClient::Client.any_instance.stub(:retrieve_proxy_granting_ticket).and_return(pgt)

      controller = mock_controller_with_session()
      CASClient::Frameworks::Rails::Filter.filter(controller).should eq(true)
     end
  end

  context "new invalid service ticket" do
     it "should return failure from filter" do

      raw_text = "<cas:serviceResponse xmlns:cas=\"http://www.yale.edu/tp/cas\">
                    <cas:authenticationFailure>Some Error Text</cas:authenticationFailure>
                  </cas:serviceResponse>"
      response = CASClient::ValidationResponse.new(raw_text)

      CASClient::Client.any_instance.stub(:request_cas_response).and_return(response)
      CASClient::Frameworks::Rails::Filter.stub(:unauthorized!) {"bogusresponse"}

      controller = mock_controller_with_session()
      CASClient::Frameworks::Rails::Filter.filter(controller).should eq(false)
     end
  end

  context "does not have new input service ticket" do
    context "with last service ticket" do
       it "should return failure from filter" do

        CASClient::Frameworks::Rails::Filter.stub(:unauthorized!) {"bogusresponse"}

        controller = mock_controller_with_session()
        controller.stub(:params) {{}}
        CASClient::Frameworks::Rails::Filter.filter(controller).should eq(false)
       end
    end

    context "sent through gateway" do
      context "gatewaying off" do
         it "should return failure from filter" do

          CASClient::Frameworks::Rails::Filter.stub(:unauthorized!) {"bogusresponse"}

          CASClient::Frameworks::Rails::Filter.config[:use_gatewaying] = false 
          controller = mock_controller_with_session()
          controller.session[:cas_sent_to_gateway] = true
          controller.stub(:params) {{}}
          CASClient::Frameworks::Rails::Filter.filter(controller).should eq(false)
         end
      end

      context "gatewaying on" do
         it "should return failure from filter" do

          CASClient::Frameworks::Rails::Filter.config[:use_gatewaying] = true 
          controller = mock_controller_with_session()
          controller.session[:cas_sent_to_gateway] = true
          controller.stub(:params) {{}}
          CASClient::Frameworks::Rails::Filter.filter(controller).should eq(true)
         end
      end
    end
  end

  context "has new input service ticket" do
    context "no PGT" do
       it "should return failure from filter" do

        raw_text = "<cas:serviceResponse xmlns:cas=\"http://www.yale.edu/tp/cas\">
                      <cas:authenticationSuccess>
                        <cas:user>rich.yarger@vibes.com</cas:user>
                        <cas:proxyGrantingTicket>PGTIOU-1308586001r29DC1F852C95930FE6694C1EFC64232A3359798893BC0B</cas:proxyGrantingTicket>
                      </cas:authenticationSuccess>
                    </cas:serviceResponse>"
        response = CASClient::ValidationResponse.new(raw_text)

        CASClient::Client.any_instance.stub(:request_cas_response).and_return(response)
        CASClient::Client.any_instance.stub(:retrieve_proxy_granting_ticket).and_raise CASClient::CASException

        controller = mock_controller_with_session()
        expect { CASClient::Frameworks::Rails::Filter.filter(controller) }.to raise_error(CASClient::CASException)
       end
    end

    context "cannot connect to CASServer" do
       it "should return failure from filter" do

        CASClient::Client.any_instance.stub(:request_cas_response).and_raise "Some exception"

        controller = mock_controller_with_session()
        expect { CASClient::Frameworks::Rails::Filter.filter(controller) }.to raise_error(RuntimeError)
       end
    end

    context "matches existing service ticket" do
      subject { Hash.new }
      it "should return successfully from filter" do

        mock_client = CASClient::Client.new()
        mock_client.should_receive(:request_cas_response).at_most(0).times
        mock_client.should_receive(:retrieve_proxy_granting_ticket).at_most(0).times
        CASClient::Frameworks::Rails::Filter.send(:class_variable_set, :@@client, mock_client)

        subject[:cas_last_valid_ticket] = 'bogusticket'
        subject[:cas_last_valid_ticket_service] = 'bogusurl'
        controller = mock_controller_with_session(mock_post_request(), subject)
        CASClient::Frameworks::Rails::Filter.filter(controller).should eq(true)
      end
    end
  end

  context "controller request is missing format" do
    context "#unauthorized!" do
      it 'should not crash' do
        request = double('mock request')
        request.stub(:format).and_return(nil)

        controller = mock_controller_with_session(request)

        CASClient::Frameworks::Rails::Filter.
          should_receive(:redirect_to_cas_for_authentication).
          with(controller)
          
        CASClient::Frameworks::Rails::Filter.unauthorized!(controller)
      end
    end
  end
end
