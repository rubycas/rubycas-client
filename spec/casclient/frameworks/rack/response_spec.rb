#require 'spec_helper'
require 'casclient/frameworks/rack/response'

describe CASClient::Frameworks::Rack::Response do

  describe 'with errors' do
    subject {
      CASClient::Frameworks::Rack::Response.new(nil, nil, "OpenSSL::SSL::SSLError")
    }

    it 'user is nil' do
      subject.user.should == nil
    end

    it 'attributes is nil' do
      subject.attributes.should == nil
    end

    it 'errors is populated' do
      subject.errors.should == ["OpenSSL::SSL::SSLError"]
    end

    it 'valid? is false' do
      subject.valid?.should == false
    end

    it 'to_s' do
      subject.to_s.should == "Errors: [\"OpenSSL::SSL::SSLError\"]"
    end

    it 'to_hash' do
      subject.to_hash.should == {errors: ["OpenSSL::SSL::SSLError"] }
    end
  end

  describe 'valid responds to' do
    let(:email) { 'name@example.com' }
    let(:attributes) { Hash[:role_names, 'headoffice,centre'] }

    subject {
      CASClient::Frameworks::Rack::Response.new(email, attributes)
    }

    it 'user match email' do
      subject.user.should == email
    end

    it 'attributes is populate' do
      subject.attributes.should == attributes
    end

    it 'errors empty' do
      subject.errors.should == []
    end

    it 'valid? is true' do
      subject.valid?.should == true
    end

    it 'to_s' do
      subject.to_s.should == "User: name@example.com, Attributes: #{attributes}, Valid?: true, Errors: []"
    end

    it 'to_hash' do
      subject.to_hash.should == {cas_user: email, cas_extra_attributes: attributes, ticket: nil }
    end

    it 'to_hash attributes are intact' do
      subject.to_hash[:cas_extra_attributes][:role_names].should == 'headoffice,centre'
    end

  end
end
