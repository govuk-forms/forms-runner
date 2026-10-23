require "rails_helper"

RSpec.describe Api::V3::FormDocumentResource do
  let(:response_data) { File.read("spec/fixtures/all_question_types_form.json") }

  let(:req_headers) { { "Accept" => "application/json" } }

  describe ".find_by_tag" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/1/versions/live", req_headers, { version: 2 }.to_json, 200
        mock.get "/api/v3/forms/1/versions/2", req_headers, response_data, 200
      end
    end

    it "gets a form document given a form id and document tag" do
      expect(described_class.find_by_tag(1, :live)).to be_truthy
    end

    it "returns a hash" do
      form_document = described_class.find_by_tag(1, :live)
      expect(form_document).to be_a Hash
      expect(form_document["steps"]).to all be_a Hash
    end

    it "raises an exception if the form does not exist" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/99/versions/draft", req_headers, nil, 404
      end

      expect {
        described_class.find_by_tag("99", :draft)
      }.to raise_error(ActiveResource::ResourceNotFound)
    end

    context "when tag is live" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v3/forms/1/versions/live", req_headers, { version: 2 }.to_json, 200
          mock.get "/api/v3/forms/1/versions/2", req_headers, response_data.to_json, 200
        end
      end

      it "returns a live form" do
        form = described_class.find_by_tag(1, :live)

        expect(form).to include("id" => 1, "name" => "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v3/forms/1/versions/live", nil, req_headers)
      end
    end

    context "when tag is draft" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v3/forms/1/versions/draft", req_headers, response_data.to_json, 200
        end
      end

      it "returns a draft form" do
        form = described_class.find_by_tag(1, :draft)

        expect(form).to include("id" => 1, "name" => "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v3/forms/1/versions/draft", nil, req_headers)
      end
    end

    context "when mode is archived" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v3/forms/1/versions/archived", req_headers, { version: 2 }.to_json, 200
          mock.get "/api/v3/forms/1/versions/2", req_headers, response_data.to_json, 200
        end
      end

      it "returns an archived form" do
        form = described_class.find_by_tag(1, :archived)

        expect(form).to include("id" => 1, "name" => "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v3/forms/1/versions/archived", nil, req_headers)
      end
    end

    context "when given options" do
      let(:request_tag_with_param) { ActiveResource::Request.new(:get, "/api/v3/forms/1/versions/live?another=1&param=value") }
      let(:request_version_with_param) { ActiveResource::Request.new(:get, "/api/v3/forms/1/versions/2?another=1&param=value") }

      before do
        mock_response = ActiveResource::Response.new("{}")
        ActiveResource::HttpMock.respond_to(request_tag_with_param => ActiveResource::Response.new({ version: 2 }.to_json),
                                            request_version_with_param => mock_response)
      end

      it "adds params to the request" do
        described_class.find_by_tag(1, :live, param: :value, another: 1)
        expect(ActiveResource::HttpMock.requests).to include request_tag_with_param
        expect(ActiveResource::HttpMock.requests).to include request_version_with_param
      end
    end
  end

  describe ".find_by_version" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/1/versions/3", req_headers, response_data, 200
      end
    end

    it "gets a form document given a form id and version number" do
      expect(described_class.find_by_version(1, 3)).to be_truthy
    end

    it "returns a hash" do
      form_document = described_class.find_by_version(1, 3)
      expect(form_document).to be_a Hash
      expect(form_document["steps"]).to all be_a Hash
    end

    it "raises an exception if the form does not exist" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/99/versions/3", req_headers, nil, 404
      end

      expect {
        described_class.find_by_version(99, 3)
      }.to raise_error(ActiveResource::ResourceNotFound)
    end

    it "raises an exception if the version does not exist" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/1/versions/5", req_headers, nil, 404
      end

      expect {
        described_class.find_by_version(1, 5)
      }.to raise_error(ActiveResource::ResourceNotFound)
    end

    context "when given options" do
      let(:request_with_param) { ActiveResource::Request.new(:get, "/api/v3/forms/1/versions/3?another=1&param=value") }

      before do
        mock_response = ActiveResource::Response.new("{}")
        ActiveResource::HttpMock.respond_to(request_with_param => mock_response)
      end

      it "adds params to the request" do
        described_class.find_by_version(1, 3, param: :value, another: 1)
        expect(ActiveResource::HttpMock.requests).to include request_with_param
      end
    end
  end

  describe ".forms_with_delivery_schedule" do
    let(:immediate_delivery_forms) { [{ form_id: 1, state: "draft" }, { form_id: 2, state: "draft" }, { form_id: 2, state: "draft" }] }
    let(:daily_delivery_forms) { [{ form_id: 3, state: "draft" }, { form_id: 4, state: "draft" }, { form_id: 4, state: "draft" }] }
    let(:weekly_delivery_forms) { [{ form_id: 5, state: "draft" }, { form_id: 5, state: "draft" }, { form_id: 5, state: "draft" }] }

    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/with-delivery-schedule/immediate", req_headers, immediate_delivery_forms.to_json, 200
        mock.get "/api/v3/forms/with-delivery-schedule/daily", req_headers, daily_delivery_forms.to_json, 200
        mock.get "/api/v3/forms/with-delivery-schedule/weekly", req_headers, weekly_delivery_forms.to_json, 200
      end
    end

    context "when requesting forms with the immediate delivery schedule" do
      it "returns an array of form ids and states" do
        form_document = described_class.forms_with_delivery_schedule("immediate")
        expect(form_document).to eq immediate_delivery_forms
      end
    end

    context "when requesting forms with the daily delivery schedule" do
      it "returns an array of form ids and states" do
        form_document = described_class.forms_with_delivery_schedule("daily")
        expect(form_document).to eq daily_delivery_forms
      end
    end

    context "when requesting forms with the weekly delivery schedule" do
      it "returns an array of form ids and states" do
        form_document = described_class.forms_with_delivery_schedule("weekly")
        expect(form_document).to eq weekly_delivery_forms
      end
    end

    it "raises an exception if the schedule is not valid" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/with-delivery-schedule/fortnightly", req_headers, nil, 404
      end

      expect {
        described_class.forms_with_delivery_schedule("fortnightly")
      }.to raise_error(ActiveResource::ResourceNotFound)
    end

    context "when given options" do
      let(:request_with_param) { ActiveResource::Request.new(:get, "/api/v3/forms/with-delivery-schedule/immediate?another=1&param=value") }

      before do
        mock_response = ActiveResource::Response.new("{}")
        ActiveResource::HttpMock.respond_to(request_with_param => mock_response)
      end

      it "adds params to the request" do
        described_class.forms_with_delivery_schedule("immediate", param: :value, another: 1)
        expect(ActiveResource::HttpMock.requests).to include request_with_param
      end
    end
  end

  describe "#as_json" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v3/forms/1/versions/live", req_headers, { version: 2 }.to_json, 200
        mock.get "/api/v3/forms/1/versions/2", req_headers, response_data, 200
      end
    end

    it "returns a hash of the form document's attributes as read from the API" do
      form_document = described_class.find_by_tag(1, :live)
      expect(form_document.as_json).to eq JSON.parse(response_data)
    end
  end
end
