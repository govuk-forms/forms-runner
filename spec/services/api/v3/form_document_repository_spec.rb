require "rails_helper"

RSpec.describe Api::V3::FormDocumentRepository do
  let(:req_headers) { { "Accept" => "application/json" } }

  let(:form_id) { "1" }
  let(:api_v3_response_data) { JSON.load_file("spec/fixtures/all_question_types_form.json") }
  let(:api_v3_welsh_response_data) { api_v3_response_data.merge(name: "Welsh form", language: "cy") }

  describe ".find_by_tag" do
    let(:form_id) { "1" }
    let(:tag) { :live }
    let(:response_data) { api_v3_response_data }
    let(:welsh_response_data) { api_v3_welsh_response_data }
    let(:language) { nil }

    before do
      allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with("1", :live).and_return(response_data)
    end

    it "returns form document" do
      form = described_class.find_by_tag(tag:, form_id:)

      expect(form).to have_attributes(form_id:, name: "All question types form")
    end

    context "with the archived tag" do
      let(:tag) { :archived }

      context "when form has been archived" do
        before do
          allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with("1", :archived).and_return(response_data)
        end

        it "returns an archived form document" do
          form = described_class.find_by_tag(tag: :archived, form_id: form_id)

          expect(form).to have_attributes(form_id: form_id, name: "All question types form")
        end
      end
    end

    context "when the form id contains non-alpha-numeric chars" do
      let(:form_id) { "<id>" }

      it "returns nil when the id contains non-alpha-numeric chars" do
        expect(described_class.find_by_tag(tag:, form_id:)).to be_nil
      end
    end

    context "when the form id is blank" do
      let(:form_id) { "" }

      it "returns nil when the id is blank" do
        expect(described_class.find_by_tag(tag:, form_id:)).to be_nil
      end
    end

    context "when the form document is not found" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with("1", :live).and_raise(ActiveResource::ResourceNotFound.new(nil))
      end

      it "returns nil" do
        expect(described_class.find_by_tag(tag:, form_id:)).to be_nil
      end
    end

    context "when called with a language param" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(form_id, tag).and_return(response_data)
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(form_id, tag, language: :cy).and_return(welsh_response_data)
      end

      context "and the language is English" do
        let(:language) { :en }

        it "does not call the FormDocumentResource with the language param" do
          described_class.find_by_tag(tag:, form_id:, language:)
          expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(form_id, tag)
        end
      end

      context "and the language is Welsh" do
        let(:language) { :cy }

        it "calls the FormDocumentResource with the language param" do
          described_class.find_by_tag(tag:, form_id:, language:)
          expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(form_id, tag, { language: })
        end
      end
    end
  end

  describe ".find_by_version" do
    let(:form_id) { "1" }
    let(:version) { 3 }
    let(:response_data) { api_v3_response_data }
    let(:welsh_response_data) { api_v3_welsh_response_data }
    let(:language) { nil }

    before do
      allow(Api::V3::FormDocumentResource).to receive(:find_by_version).with("1", 3).and_return(response_data)
    end

    it "returns form document" do
      form = described_class.find_by_version(version:, form_id:)

      expect(form).to have_attributes(form_id:, name: "All question types form")
    end

    context "when the form id contains non-alpha-numeric chars" do
      let(:form_id) { "<id>" }

      it "returns nil when the id contains non-alpha-numeric chars" do
        expect(described_class.find_by_version(version:, form_id:)).to be_nil
      end
    end

    context "when the version id contains non-numeric chars" do
      let(:version) { "a" }

      it "returns nil when the id contains non-alpha-numeric chars" do
        expect(described_class.find_by_version(version:, form_id:)).to be_nil
      end
    end

    context "when the form id is blank" do
      let(:form_id) { "" }

      it "returns nil when the id is blank" do
        expect(described_class.find_by_version(version:, form_id:)).to be_nil
      end
    end

    context "when the form document is not found" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_version).with(form_id, version).and_raise(ActiveResource::ResourceNotFound.new(nil))
      end

      it "returns nil" do
        expect(described_class.find_by_version(version:, form_id:)).to be_nil
      end
    end

    context "when called with a language param" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_version).with(form_id, version).and_return(response_data)
        allow(Api::V3::FormDocumentResource).to receive(:find_by_version).with(form_id, version, language: :cy).and_return(welsh_response_data)
      end

      context "and the language is English" do
        let(:language) { :en }

        it "does not call the FormDocumentResource with the language param" do
          described_class.find_by_version(version:, form_id:, language:)
          expect(Api::V3::FormDocumentResource).to have_received(:find_by_version).with(form_id, version)
        end
      end

      context "and the language is Welsh" do
        let(:language) { :cy }

        it "calls the FormDocumentResource with the language param" do
          described_class.find_by_version(version:, form_id:, language:)
          expect(Api::V3::FormDocumentResource).to have_received(:find_by_version).with(form_id, version, language:)
        end
      end
    end
  end

  describe ".find_with_mode" do
    before do
      allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :draft).and_return(api_v3_response_data)
    end

    it "finds a form document given a form id and document tag" do
      expect(described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"))).to be_truthy
    end

    it "returns a FormDocumentResource model" do
      form_snapshot = described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"))
      expect(form_snapshot).to be_a Api::V3::FormDocumentResource
      expect(form_snapshot.steps).to all be_a Api::V2::StepResource
    end

    context "when the form document is not found" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :draft).and_raise(ActiveResource::ResourceNotFound.new(nil))
      end

      it "returns nil" do
        expect(described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"))).to be_nil
      end
    end

    context "when mode is live" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :live).and_return(api_v3_response_data)
      end

      it "gets a live form document from FormDocumentResource" do
        described_class.find_with_mode(form_id: 1, mode: Mode.new("live"))

        expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(1, :live)
      end
    end

    context "when mode is draft" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :draft).and_return(api_v3_response_data)
      end

      it "gets a draft form document from FormDocumentResource" do
        described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"))

        expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(1, :draft)
      end
    end

    context "when mode is archived" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :archived).and_return(api_v3_response_data)
      end

      it "gets an archived form document from FormDocumentResource" do
        described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-archived"))

        expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(1, :archived)
      end
    end

    context "when mode is preview live" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :live).and_return(api_v3_response_data)
      end

      it "gets a live form document from FormDocumentResource" do
        described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-live"))

        expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(1, :live)
      end
    end

    context "when validating the provided form id" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).and_return(api_v3_response_data)
      end

      it "returns nil when the id contains non-alpha-numeric chars" do
        expect(described_class.find_with_mode(form_id: "<id>", mode: Mode.new("preview-draft"))).to be_nil
      end

      it "returns nil when the id is blank" do
        expect(described_class.find_with_mode(form_id: "", mode: Mode.new("preview-draft"))).to be_nil
      end

      it "returns the form when the id is alphanumeric" do
        form = described_class.find_with_mode(form_id: "Alpha123", mode: Mode.new("preview-draft"))

        expect(form).to have_attributes(name: "All question types form")
      end
    end

    context "when called with a language param" do
      before do
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :draft).and_return(api_v3_response_data)
        allow(Api::V3::FormDocumentResource).to receive(:find_by_tag).with(1, :draft, language: :cy).and_return(api_v3_welsh_response_data)
      end

      context "and the language is English" do
        let(:language) { :en }

        it "does not call the FormDocumentResource with the language param" do
          described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"), language:)
          expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(1, :draft)
        end
      end

      context "and the language is Welsh" do
        let(:language) { :cy }

        it "calls the FormDocumentResource with the language param" do
          described_class.find_with_mode(form_id: 1, mode: Mode.new("preview-draft"), language:)
          expect(Api::V3::FormDocumentResource).to have_received(:find_by_tag).with(1, :draft, { language: })
        end
      end
    end
  end
end
