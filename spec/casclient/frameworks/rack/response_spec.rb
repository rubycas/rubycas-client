require 'spec_helper'
require 'casclient/frameworks/rack/response'

describe CASClient::Frameworks::Rack::Response do

#   subject {
#     CASClient::Frameworks::Rack::Response.new(nil, nil, "OpenSSL::SSL::SSLError #{err}")
#   }

  describe 'valid responds to' do
    let(:email) { 'name@example.com' }
    let(:attributes) { {role_names: 'headoffice,centre'} }

    subject {
      CASClient::Frameworks::Rack::Response.new(email, attributes)
    }

    it 'user' do
      subject.user.should == email
    end

    it 'attributes' do
      subject.attributes.should == attributes
    end

    it 'errors' do
      subject.errors.should == []
    end

    it 'valid?' do
      subject.valid?.should == true
    end


  end
end
