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
      <cas:mobile_phone></cas:mobile_phone>
      <cas:global_roles><![CDATA[]]></cas:global_roles>
      <cas:foo_data> <![CDATA[[{"id":10529}]]]></cas:foo_data>
    </cas:attributes>
  </cas:authenticationSuccess>
</cas:serviceResponse>
RESPONSE_TEXT
    end

    let(:subject) { CASClient::ValidationResponse.new response_text, :encode_extra_attributes_as => :json }

    it "sets the value of non-CDATA escaped empty attribute to nil" do
      subject.extra_attributes["mobile_phone"].should be_nil
    end

    it "sets the value of CDATA escaped empty attribute to nil" do
      subject.extra_attributes["global_roles"].should be_nil
    end

    it "sets the value of literal attributes to their value" do
      subject.extra_attributes["first_name"].should == "Jack"
    end

    it "sets the value of JSON attributes to their parsed value" do
      subject.extra_attributes["foo_data"][0]["id"].should == 10529
    end
  end
end
