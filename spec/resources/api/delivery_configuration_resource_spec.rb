require "rails_helper"

RSpec.describe Api::DeliveryConfigurationResource do
  let(:req_headers) { { "Accept" => "application/json" } }

  describe ".from_form" do
    let(:draft_delivery_configurations) { [build(:delivery_configuration, :immediate_email), build(:delivery_configuration, :weekly_email)] }
    let(:live_delivery_configurations)  { [build(:delivery_configuration, :immediate_email), build(:delivery_configuration, :daily_email)] }

    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/1/delivery-configurations/draft", req_headers, draft_delivery_configurations.to_json, 200
        mock.get "/api/v3/forms/1/delivery-configurations/current", req_headers, live_delivery_configurations.to_json, 200
      end
    end

    it "gets the draft delivery configuration for a form" do
      expect(described_class.from_form(1, draft: true)).to eq(draft_delivery_configurations.map { |delivery_configuration| described_class.new(delivery_configuration.to_h) })
    end

    it "gets the live delivery configuration for a form" do
      expect(described_class.from_form(1)).to eq(live_delivery_configurations.map { |delivery_configuration| described_class.new(delivery_configuration.to_h) })
    end
  end
end
