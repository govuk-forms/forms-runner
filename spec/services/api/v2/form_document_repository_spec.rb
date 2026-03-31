require "rails_helper"

RSpec.describe Api::V2::FormDocumentRepository do
  let(:req_headers) { { "Accept" => "application/json" } }

  let(:form_id) { "1" }
  let(:api_v2_response_data) { JSON.load_file("spec/fixtures/all_question_types_form.json") }
  let(:api_v2_welsh_response_data) { api_v2_response_data.merge(name: "Welsh form", language: "cy") }

  describe ".find" do
    let(:form_id) { "1" }
    let(:tag) { :live }
    let(:response_data) { api_v2_response_data.to_json }
    let(:welsh_response_data) { api_v2_welsh_response_data.to_json }
    let(:status) { 200 }
    let(:language) { nil }

    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/#{form_id}/#{tag}", req_headers, response_data, status
        mock.get "/api/v2/forms/#{form_id}/#{tag}?language=cy", req_headers, welsh_response_data, status
      end
    end

    it "returns a form" do
      form = described_class.find(tag:, form_id:)

      expect(form).to have_attributes(form_id:, name: "All question types form")
    end

    it "attaches the form document JSON to the form" do
      form = described_class.find(tag:, form_id:)

      expect(form.document_json).to eq api_v2_response_data
    end

    context "with the archived tag" do
      let(:tag) { :archived }

      context "when a form has been archived" do
        it "returns an archived form" do
          form = described_class.find(tag: :archived, form_id: form_id)

          expect(form).to have_attributes(form_id: form_id, name: "All question types form")
        end
      end

      context "when a form has not been archived" do
        let(:response_data) { nil }
        let(:status) { 404 }

        it "returns nil" do
          expect(described_class.find(tag: :archived, form_id: form_id)).to be_nil
        end
      end
    end

    context "when the form id contains non-alpha-numeric chars" do
      let(:form_id) { "<id>" }

      it "returns nil when the id contains non-alpha-numeric chars" do
        expect(described_class.find(tag:, form_id:)).to be_nil
      end
    end

    context "when the form id is blank" do
      let(:form_id) { "" }

      it "returns nil when the id is blank" do
        expect(described_class.find(tag:, form_id:)).to be_nil
      end
    end

    context "when the form does not exist" do
      let(:form_id) { "99" }
      let(:response_data) { nil }
      let(:status) { 404 }

      it "returns nil" do
        expect(described_class.find(tag:, form_id:)).to be_nil
      end
    end

    context "when given language makes correct request" do
      let(:request_with_no_language_param) { ActiveResource::Request.new(:get, "/api/v2/forms/#{form_id}/#{tag}", req_headers) }
      let(:request_with_language_param_cy) { ActiveResource::Request.new(:get, "/api/v2/forms/#{form_id}/#{tag}?language=cy", req_headers) }

      before do
        mock_response = ActiveResource::Response.new(response_data)
        ActiveResource::HttpMock.respond_to(request_with_no_language_param => mock_response,
                                            request_with_language_param_cy => mock_response)
      end

      it "given :en makes request wihout the language param" do
        described_class.find(tag:, form_id:, language: :en)
        expect(ActiveResource::HttpMock.requests).to include request_with_no_language_param
      end

      it "given :cy makes request with the language param" do
        described_class.find(tag:, form_id:, language: :cy)
        expect(ActiveResource::HttpMock.requests).to include request_with_language_param_cy
      end
    end
  end

  describe ".find_with_mode" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/forms/1/draft", req_headers, api_v2_response_data.merge(name: "Draft form").to_json, 200
        mock.get "/api/v2/forms/1/live", req_headers, api_v2_response_data.merge(name: "Live form").to_json, 200
        mock.get "/api/v2/forms/1/archived", req_headers, api_v2_response_data.merge(name: "Archived form").to_json, 200
        mock.get "/api/v2/forms/2/live", req_headers, nil, 404
        mock.get "/api/v2/forms/2/archived", req_headers, api_v2_response_data.to_json, 200
        mock.get "/api/v2/forms/Alpha123/draft", req_headers, api_v2_response_data.merge("form_id": "Alpha123").to_json, 200
        mock.get "/api/v2/forms/99/draft", req_headers, nil, 404
      end
    end

    it "finds a form snapshot given a form id and document tag" do
      expect(described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"))).to be_truthy
    end

    it "returns a form model" do
      form_snapshot = described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"))
      expect(form_snapshot).to be_a Form
      expect(form_snapshot.form_document_steps).to all be_a FormDocumentStep
    end

    it "returns nil if the form does not exist" do
      expect(described_class.find_with_mode(form_id: "99", mode: Mode.new("preview-draft"))).to be_nil
    end

    context "when mode is live" do
      it "returns a live form" do
        form = described_class.find_with_mode(form_id: "1", mode: Mode.new("live"))

        expect(form).to have_attributes(form_id: "1", name: "Live form")
      end
    end

    context "when mode is draft" do
      it "returns a draft form" do
        form = described_class.find_with_mode(form_id: "1", mode: Mode.new("preview-draft"))

        expect(form).to have_attributes(form_id: "1", name: "Draft form")
      end
    end

    context "when mode is archived" do
      it "returns an archived form" do
        form = described_class.find_with_mode(form_id: "1", mode: Mode.new("preview-archived"))

        expect(form).to have_attributes(form_id: "1", name: "Archived form")
      end
    end

    context "when mode is preview live" do
      it "returns a live form" do
        form = described_class.find_with_mode(form_id: "1", mode: Mode.new("preview-live"))

        expect(form).to have_attributes(form_id: "1", name: "Live form")
      end
    end

    context "when validating the provided form id" do
      it "returns nil when the id contains non-alpha-numeric chars" do
        expect(described_class.find_with_mode(form_id: "<id>", mode: Mode.new("preview-draft"))).to be_nil
      end

      it "returns nil when the id is blank" do
        expect(described_class.find_with_mode(form_id: "", mode: Mode.new("preview-draft"))).to be_nil
      end

      it "returns the form when the id is alphanumeric" do
        form = described_class.find_with_mode(form_id: "Alpha123", mode: Mode.new("preview-draft"))

        expect(form).to have_attributes(form_id: "Alpha123", name: "All question types form")
      end
    end

    context "when Welsh form requested" do
      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/forms/1/live?language=cy", req_headers, api_v2_welsh_response_data.to_json, 200
        end
      end

      it "returns Welsh form model" do
        form = described_class.find_with_mode(form_id: "1", mode: Mode.new("live"), language: :cy)
        expect(form).to have_attributes(form_id: "1", name: "Welsh form", language: :cy)
      end
    end
  end
end
