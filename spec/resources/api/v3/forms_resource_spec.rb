require "rails_helper"

RSpec.describe Api::V3::FormsResource do
  let(:req_headers) { { "Accept" => "application/json" } }

  describe ".with_delivery_schedule" do
    let(:immediate_delivery_forms) { [{ form_id: 1, state: "draft" }, { form_id: 2, state: "draft" }, { form_id: 2, state: "draft" }] }
    let(:daily_delivery_forms) { [{ form_id: 3, state: "draft" }, { form_id: 4, state: "draft" }, { form_id: 4, state: "draft" }] }
    let(:weekly_delivery_forms) { [{ form_id: 5, state: "draft" }, { form_id: 5, state: "draft" }, { form_id: 5, state: "draft" }] }

    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms?delivery_schedule=immediate", req_headers, immediate_delivery_forms.to_json, 200
        mock.get "/api/v3/forms?delivery_schedule=daily", req_headers, daily_delivery_forms.to_json, 200
        mock.get "/api/v3/forms?delivery_schedule=weekly", req_headers, weekly_delivery_forms.to_json, 200
      end
    end

    context "when requesting forms with the immediate delivery schedule" do
      it "returns an array of form ids and states" do
        form_document = described_class.with_delivery_schedule("immediate")
        expect(form_document).to eq immediate_delivery_forms
      end
    end

    context "when requesting forms with the daily delivery schedule" do
      it "returns an array of form ids and states" do
        form_document = described_class.with_delivery_schedule("daily")
        expect(form_document).to eq daily_delivery_forms
      end
    end

    context "when requesting forms with the weekly delivery schedule" do
      it "returns an array of form ids and states" do
        form_document = described_class.with_delivery_schedule("weekly")
        expect(form_document).to eq weekly_delivery_forms
      end
    end

    it "raises an exception if the schedule is not valid" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms?delivery_schedule=fortnightly", req_headers, "", 400
      end

      expect {
        described_class.with_delivery_schedule("fortnightly")
      }.to raise_error(ActiveResource::BadRequest)
    end

    context "when given options" do
      let(:request_with_param) { ActiveResource::Request.new(:get, "/api/v3/forms?another=1&delivery_schedule=immediate&param=value") }

      before do
        mock_response = ActiveResource::Response.new("{}")
        ActiveResource::HttpMock.respond_to(request_with_param => mock_response)
      end

      it "adds params to the request" do
        described_class.with_delivery_schedule("immediate", param: :value, another: 1)
        expect(ActiveResource::HttpMock.requests).to include request_with_param
      end
    end
  end
end
