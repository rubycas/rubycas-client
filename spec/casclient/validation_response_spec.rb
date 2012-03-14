require 'spec_helper'
require 'casclient/responses.rb'

describe CASClient::ValidationResponse do
  context "when parsing extra attributes as JSON" do
    let(:response_text) do
<<RESPONSE_TEXT
<cas:serviceResponse xmlns:cas="http://www.yale.edu/tp/cas">
  <cas:authenticationSuccess>
    <cas:attributes>
      <cas:first_name>Jack</cas:first_name>
      <cas:last_name>92.5</cas:last_name>
      <cas:mobile_phone></cas:mobile_phone>
      <cas:global_roles><![CDATA[]]></cas:global_roles>
      <cas:foo_data> <![CDATA[[{"id":10529}]]]></cas:foo_data>
      <cas:food_data> <![CDATA[{"id":10529}]]></cas:food_data>
      <cas:allegedly_yaml>- 10</cas:allegedly_yaml>
    </cas:attributes>
  </cas:authenticationSuccess>
</cas:serviceResponse>
RESPONSE_TEXT
    end

    let(:other_response_text) do
<<RESPONSE_TEXT
<?xml version="1.0" encoding="UTF-8"?>
<cas:serviceResponse xmlns:cas="http://www.yale.edu/tp/cas">
  <cas:authenticationSuccess>
    <cas:user>myuser</cas:user>
    <cas:attribute name="username" value="myuser"/>
    <cas:attribute name="name" value="My User"/>
    <cas:attribute name="email" value="myuser@mail.example.com"/>
  </cas:authenticationSuccess>
</cas:serviceResponse>
RESPONSE_TEXT
    end

    let(:subject) { CASClient::ValidationResponse.new response_text, :encode_extra_attributes_as => :json }
    let(:other_subject) { CASClient::ValidationResponse.new other_response_text }

    it "sets the value of non-CDATA escaped empty attribute to nil" do
      subject.extra_attributes["mobile_phone"].should be_nil
    end

    it "sets the value of CDATA escaped empty attribute to nil" do
      subject.extra_attributes["global_roles"].should be_nil
    end

    it "sets the value of literal attributes to their value" do
      subject.extra_attributes["first_name"].should == "Jack"
    end

    it "sets the value of JSON attributes containing Arrays to their parsed value" do
      subject.extra_attributes["foo_data"][0]["id"].should == 10529
    end

    it "sets the value of JSON attributes containing Hashes to their parsed value" do
      subject.extra_attributes["food_data"]["id"].should == 10529
    end

    it "sets non-hash attributes as strings" do
      subject.extra_attributes["last_name"].should be_a_kind_of String
    end

    it "sets the value of attributes which are not valid JSON but are valid YAML to their literal value" do
      subject.extra_attributes["allegedly_yaml"].should == '- 10'
    end

    it "sets attributes for other type of format" do
      expected = {"username" => "myuser", "name" => 'My User', "email" => 'myuser@mail.example.com'}
      other_subject.user.should == 'myuser'
      other_subject.extra_attributes.should == expected
    end
  end
end
