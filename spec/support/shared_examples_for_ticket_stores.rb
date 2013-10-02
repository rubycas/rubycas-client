shared_examples "a ticket store interacting with sessions" do
  describe "#store_service_session_lookup" do
    it "should raise CASException if the Service Ticket is nil" do
      expect { subject.store_service_session_lookup(nil, "controller") }.to raise_exception(CASClient::CASException, /No service_ticket specified/)
    end
    it "should raise CASException if the controller is nil" do
      expect { subject.store_service_session_lookup("service_ticket", nil) }.to raise_exception(CASClient::CASException, /No controller specified/)
    end
    it "should store the ticket without any errors" do
      expect { subject.store_service_session_lookup(service_ticket, mock_controller_with_session(nil, session)) }.to_not raise_exception
    end
  end

  describe "#get_session_for_service_ticket" do
    context "the service ticket is nil" do
      it "should raise CASException" do
        expect { subject.get_session_for_service_ticket(nil) }.to raise_exception(CASClient::CASException, /No service_ticket specified/)
      end
    end
    context "the service ticket is associated with a session" do
      before do
        subject.store_service_session_lookup(service_ticket, mock_controller_with_session(nil, session))
        session.save!
      end
      it "should return the session_id and session for the given service ticket" do
        result_session_id, result_session = subject.get_session_for_service_ticket(service_ticket)
        result_session_id.should == session.session_id
        result_session.session_id.should == session.session_id
        result_session.data.should == session.data
      end
    end
    context "the service ticket is not associated with a session" do
      it "should return nils if there is no session for the given service ticket" do
        subject.get_session_for_service_ticket(service_ticket).should == [nil, nil]
      end
    end
  end

  describe "#process_single_sign_out" do
    context "the service ticket is nil" do
      it "should raise CASException" do
        expect { subject.process_single_sign_out(nil) }.to raise_exception(CASClient::CASException, /No service_ticket specified/)
      end
    end
    context "the service ticket is associated with a session" do
      before do
        subject.store_service_session_lookup(service_ticket, mock_controller_with_session(nil, session))
        session.save!
        subject.process_single_sign_out(service_ticket)
      end
      context "the session" do
        it "should be destroyed" do
          ActiveRecord::SessionStore.session_class.find(:first, :conditions => {:session_id => session.session_id}).should be_nil
        end
      end
      it "should destroy session for the given service ticket" do
        subject.process_single_sign_out(service_ticket)
      end
    end
    context "the service ticket is not associated with a session" do
      it "should run without error if there is no session for the given service ticket" do
        expect { subject.process_single_sign_out(service_ticket) }.to_not raise_error
      end
    end
  end

  describe "#cleanup_service_session_lookup" do
    context "the service ticket is nil" do
      it "should raise CASException" do
        expect { subject.cleanup_service_session_lookup(nil) }.to raise_exception(CASClient::CASException, /No service_ticket specified/)
      end
    end
    it "should run without error" do
      expect { subject.cleanup_service_session_lookup(service_ticket) }.to_not raise_exception
    end
  end
end

shared_examples "a ticket store" do
  let(:ticket_store) { described_class.new }
  let(:service_url) { "https://www.example.com/cas" }
  let(:session) do
    ActiveRecord::SessionStore::Session.create!(:session_id => "session#{rand(1000)}", :data => {})
  end
  subject { ticket_store }

  context "when dealing with sessions, Service Tickets, and Single Sign Out" do
    context "and the service ticket is a String" do
      it_behaves_like "a ticket store interacting with sessions" do
        let(:service_ticket) { "ST-ABC#{rand(1000)}" }
      end
    end
    context "and the service ticket is a ServiceTicket" do
      it_behaves_like "a ticket store interacting with sessions" do
        let(:service_ticket) { CASClient::ServiceTicket.new("ST-ABC#{rand(1000)}", service_url) }
      end
    end
    context "and the service ticket is a ProxyTicket" do
      it_behaves_like "a ticket store interacting with sessions" do
        let(:service_ticket) { CASClient::ProxyTicket.new("ST-ABC#{rand(1000)}", service_url) }
      end
    end
  end

  context "when dealing with Proxy Granting Tickets and their IOUs" do
    let(:pgt) { "my_pgt_#{rand(1000)}" }
    let(:pgt_iou) { "my_pgt_iou_#{rand(1000)}" }

    describe "#save_pgt_iou" do
      it "should raise CASClient::CASException if the pgt_iou is nil" do
        expect { subject.save_pgt_iou(nil, pgt) }.to raise_exception(CASClient::CASException, /Invalid pgt_iou/)
      end
      it "should raise CASClient::CASException if the pgt is nil" do
        expect { subject.save_pgt_iou(pgt_iou, nil) }.to raise_exception(CASClient::CASException, /Invalid pgt/)
      end
    end

    describe "#retrieve_pgt" do
      before do
        subject.save_pgt_iou(pgt_iou, pgt)
      end

      it "should return the stored pgt" do
        subject.retrieve_pgt(pgt_iou).should == pgt
      end

      it "should raise CASClient::CASException if the pgt_iou isn't in the store" do
        expect { subject.retrieve_pgt("not_my"+pgt_iou) }.to raise_exception(CASClient::CASException, /Invalid pgt_iou/)
      end

      it "should not return the stored pgt a second time" do
        subject.retrieve_pgt(pgt_iou).should == pgt
        expect { subject.retrieve_pgt(pgt_iou) }.to raise_exception(CASClient::CASException, /Invalid pgt_iou/)
      end
    end
  end
end
