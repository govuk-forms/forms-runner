require "rails_helper"

RSpec.describe Api::V2::FormDocumentResource do
  let(:response_data) { File.read("spec/fixtures/all_question_types_form.json") }

  let(:req_headers) { { "Accept" => "application/json" } }

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/1/live", req_headers, response_data, 200
    end
  end

  describe ".find" do
    it "finds a form document given a form id and document tag" do
      expect(described_class.find(1, :live)).to be_truthy
    end

    it "returns a v2 API form document" do
      form_document = described_class.find(1, :live)
      expect(form_document).to be_a described_class
      expect(form_document.steps).to all be_a Api::V2::StepResource
    end

    it "raises an exception if the form does not exist" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/99/draft", req_headers, nil, 404
      end

      expect {
        described_class.find("99", :draft)
      }.to raise_error(ActiveResource::ResourceNotFound)
    end

    context "when tag is live" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/forms/1/live", req_headers, response_data.to_json, 200
        end
      end

      it "returns a live form" do
        form = described_class.find(1, :live)

        expect(form).to have_attributes(id: 1, name: "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v2/forms/1/live", nil, req_headers)
      end
    end

    context "when tag is draft" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/forms/1/draft", req_headers, response_data.to_json, 200
        end
      end

      it "returns a draft form" do
        form = described_class.find(1, :draft)

        expect(form).to have_attributes(id: 1, name: "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v2/forms/1/draft", nil, req_headers)
      end
    end

    context "when mode is archived" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/forms/1/archived", req_headers, response_data.to_json, 200
        end
      end

      it "returns an archived form" do
        form = described_class.find(1, :archived)

        expect(form).to have_attributes(id: 1, name: "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v2/forms/1/archived", nil, req_headers)
      end
    end

    context "when given params" do
      let(:request_with_language_param) { ActiveResource::Request.new(:get, "/api/v2/forms/1/live?language=cy") }

      before do
        mock_response = ActiveResource::Response.new("{}")
        ActiveResource::HttpMock.respond_to(request_with_language_param => mock_response)
      end

      it "adds params to the request" do
        described_class.get(1, :live, language: :cy)
        expect(ActiveResource::HttpMock.requests).to include request_with_language_param
      end
    end
  end

  describe ".get" do
    it "gets a form document given a form id and document tag" do
      expect(described_class.get(1, :live)).to be_truthy
    end

    it "returns a hash" do
      form_document = described_class.get(1, :live)
      expect(form_document).to be_a Hash
      expect(form_document["steps"]).to all be_a Hash
    end

    it "raises an exception if the form does not exist" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/99/draft", req_headers, nil, 404
      end

      expect {
        described_class.get("99", :draft)
      }.to raise_error(ActiveResource::ResourceNotFound)
    end

    context "when tag is live" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/forms/1/live", req_headers, response_data.to_json, 200
        end
      end

      it "returns a live form" do
        form = described_class.get(1, :live)

        expect(form).to include("id" => 1, "name" => "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v2/forms/1/live", nil, req_headers)
      end
    end

    context "when tag is draft" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/forms/1/draft", req_headers, response_data.to_json, 200
        end
      end

      it "returns a draft form" do
        form = described_class.get(1, :draft)

        expect(form).to include("id" => 1, "name" => "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v2/forms/1/draft", nil, req_headers)
      end
    end

    context "when mode is archived" do
      let(:response_data) { { id: 1, name: "form name", steps: [] } }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/forms/1/archived", req_headers, response_data.to_json, 200
        end
      end

      it "returns an archived form" do
        form = described_class.get(1, :archived)

        expect(form).to include("id" => 1, "name" => "form name")

        expect(ActiveResource::HttpMock.requests)
          .to include ActiveResource::Request.new(:get, "/api/v2/forms/1/archived", nil, req_headers)
      end
    end

    context "when given options" do
      let(:request_with_param) { ActiveResource::Request.new(:get, "/api/v2/forms/1/live?another=1&param=value") }

      before do
        mock_response = ActiveResource::Response.new("{}")
        ActiveResource::HttpMock.respond_to(request_with_param => mock_response)
      end

      it "adds params to the request" do
        described_class.get(1, :live, param: :value, another: 1)
        expect(ActiveResource::HttpMock.requests).to include request_with_param
      end
    end
  end

  describe "#as_json" do
    it "returns a hash of the form document's attributes as read from the API" do
      form_document = described_class.find(1, :live)
      expect(form_document.as_json).to eq JSON.parse(response_data)
    end
  end
end
