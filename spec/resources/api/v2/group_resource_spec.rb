require "rails_helper"

RSpec.describe Api::V2::GroupResource do
  let(:req_headers) { { "Accept" => "application/json" } }
  let(:group) { build :group }
  let(:form_id) { 123 }

  describe ".find" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/#{form_id}/group", req_headers, group.to_json, 200
      end
    end

    it "finds a group for a given form ID" do
      group = described_class.find(form_id)
      expect(group).to be_a(described_class)
    end
  end
end
