require 'teststrap'
require 'casclient/frameworks/rails/filter'

context CASClient::Frameworks::Rails::Filter do
  helper(:controller_with_session) do |session|
    controller = Object.new
    stub(controller).session {session}
    controller
  end
  setup do
    CASClient::Frameworks::Rails::Filter.configure(
      :cas_base_url => 'http://test.local/',
      :logger => stub!
    )
  end
  context "that has fake called with a username" do
    setup { CASClient::Frameworks::Rails::Filter.fake('tester@test.com') }
    should 'set the session user on #filter' do
      setup { Hash.new }
      CASClient::Frameworks::Rails::Filter.filter(controller_with_session(topic))
      topic
    end.equals :cas_user => 'tester@test.com', :casfilteruser => 'tester@test.com'
  end
  context "that has fake called with a username and attributes" do
    setup { CASClient::Frameworks::Rails::Filter.fake('tester@test.com', {:test => 'stuff', :this => 'that'}) }
    should 'set the session user and attributes on #filter' do
      setup { Hash.new }
      CASClient::Frameworks::Rails::Filter.filter(controller_with_session(topic))
      topic
    end.equals :cas_user => 'tester@test.com', :casfilteruser => 'tester@test.com', :cas_extra_attributes => {:test => 'stuff', :this => 'that' }
  end
end
