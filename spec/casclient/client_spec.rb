require 'spec_helper'

describe CASClient::Client do
  let(:client)     { CASClient::Client.new(:login_url => login_url, :cas_base_url => '')}
  let(:login_url)  { "http://localhost:3443/"}
  let(:uri)        { URI.parse(login_url) }
  let(:session)    { double('session', :use_ssl= => true, :verify_mode= => true) }

  context "https connection" do
    let(:proxy)      { double('proxy', :new => session) }

    before :each do
      Net::HTTP.stub :Proxy => proxy
    end

    it "sets up the session with the login url host and port" do
      proxy.should_receive(:new).with('localhost', 3443).and_return(session)
      client.send(:https_connection, uri)
    end
    
    it "sets up the proxy with the known proxy host and port" do
      client = CASClient::Client.new(:login_url => login_url, :cas_base_url => '', :proxy_host => 'foo', :proxy_port => 1234)
      Net::HTTP.should_receive(:Proxy).with('foo', 1234).and_return(proxy)
      client.send(:https_connection, uri)
    end
  end
  
  context "cas server requests" do
    let(:response)   { double('response', :body => 'HTTP BODY', :code => '200') }
    let(:connection) { double('connection', :get => response, :post => response, :request => response) }

    before :each do
      client.stub(:https_connection).and_return(session)
      session.stub(:start).and_yield(connection)
    end
    
    context "cas server is up" do
      it "returns false if the server cannot be connected to" do
        connection.stub(:get).and_raise(Errno::ECONNREFUSED)
        client.cas_server_is_up?.should be_false
      end
    
      it "returns false if the request was not a success" do
        response.stub :kind_of? => false
        client.cas_server_is_up?.should be_false
      end
      
      it "returns true when the server is running" do
        response.stub :kind_of? => true
        client.cas_server_is_up?.should be_true
      end
    end
    
    context "request login ticket" do
      it "raises an exception when the request was not a success" do
        session.stub(:post).with("/Ticket", ";").and_return(response)
        response.stub :kind_of? => false
        lambda {
          client.request_login_ticket
        }.should raise_error(CASClient::CASException)
      end
      
      it "returns the response body when the request is a success" do
        session.stub(:post).with("/Ticket", ";").and_return(response)
        response.stub :kind_of? => true
        client.request_login_ticket.should == "HTTP BODY"
      end
    end
    
    context "request cas response" do
      let(:validation_response) { double('validation_response') }
      
      it "should raise an exception when the request is not a success or 422" do
        response.stub :kind_of? => false
        lambda {
          client.send(:request_cas_response, uri, CASClient::ValidationResponse)
        }.should raise_error(RuntimeError)
      end
      
      it "should return a ValidationResponse object when the request is a success or 422" do
        CASClient::ValidationResponse.stub(:new).and_return(validation_response)
        response.stub :kind_of? => true
        client.send(:request_cas_response, uri, CASClient::ValidationResponse).should == validation_response
      end
    end
    
    context "submit data to cas" do
      it "should return an HTTPResponse" do
        client.send(:submit_data_to_cas, uri, {}).should == response
      end
    end
  end
end
