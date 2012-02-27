require 'spec_helper'
require 'support/local_hash_ticket_store'
require 'fileutils'

describe CASClient::Tickets::Storage::AbstractTicketStore do
  describe "#store_service_session_lookup" do
    it "should raise an exception" do
      expect { subject.store_service_session_lookup("service_ticket", mock_controller_with_session) }.to raise_exception 'Implement this in a subclass!'
    end
  end
  describe "#cleanup_service_session_lookup" do
    it "should raise an exception" do
      expect { subject.cleanup_service_session_lookup("service_ticket") }.to raise_exception 'Implement this in a subclass!'
    end
  end
  describe "#save_pgt_iou" do
    it "should raise an exception" do
      expect { subject.save_pgt_iou("pgt_iou", "pgt") }.to raise_exception 'Implement this in a subclass!'
    end
  end
  describe "#retrieve_pgt" do
    it "should raise an exception" do
      expect { subject.retrieve_pgt("pgt_iou") }.to raise_exception 'Implement this in a subclass!'
    end
  end
  describe "#get_session_for_service_ticket" do
    it "should raise an exception" do
      expect { subject.get_session_for_service_ticket("service_ticket") }.to raise_exception 'Implement this in a subclass!'
    end
  end
end

describe CASClient::Tickets::Storage::LocalDirTicketStore do
  let(:dir) {File.join(SPEC_TMP_DIR, "local_dir_ticket_store")}
  before do
    FileUtils.mkdir_p(File.join(dir, "sessions"))
  end
  after do
    FileUtils.remove_dir(dir)
  end
  it_should_behave_like "a ticket store" do
    let(:ticket_store) {described_class.new(:storage_dir => dir)}
  end
end
