require 'spec_helper'
require 'casclient/tickets/storage/active_record_ticket_store'

describe CASClient::Tickets::Storage::ActiveRecordTicketStore do
  it_should_behave_like "a ticket store"
end
