require "rails_helper"

RSpec.describe IncompleteSubmission, type: :model do
  subject(:incomplete_submission) do
    described_class.new(user_id: "one-login-sub", form_id: 1, form_version: 1, answers: {})
  end

  describe "validations" do
    it "is valid with a user_id and form_id" do
      expect(incomplete_submission).to be_valid
    end

    context "without a user_id" do
      before { incomplete_submission.user_id = nil }

      it "is invalid" do
        expect(incomplete_submission).not_to be_valid
        expect(incomplete_submission.errors[:user_id]).to include("can't be blank")
      end
    end

    context "without a form_id" do
      before { incomplete_submission.form_id = nil }

      it "is invalid" do
        expect(incomplete_submission).not_to be_valid
        expect(incomplete_submission.errors[:form_id]).to include("can't be blank")
      end
    end

    context "when an incomplete submission already exists for the same user and form" do
      before { described_class.create!(user_id: incomplete_submission.user_id, form_id: incomplete_submission.form_id) }

      it "is invalid" do
        expect(incomplete_submission).not_to be_valid
        expect(incomplete_submission.errors[:form_id]).to include("has already been taken")
      end
    end
  end

  describe "database constraints" do
    it "rejects a duplicate (user_id, form_id) that bypasses validation" do
      described_class.create!(user_id: "one-login-sub", form_id: 1)
      duplicate = described_class.new(user_id: "one-login-sub", form_id: 1)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#form" do
    let(:form_document) { Api::V3::FormDocumentResource.new(name: "English form") }

    before do
      allow(Api::V3::FormDocumentRepository).to receive(:find_by_version)
                                                  .with(form_id: 1, version: 1, language: :en)
                                                  .and_return(form_document)
    end

    it "returns a Form built from the English form document for the saved version" do
      form = incomplete_submission.form

      expect(form).to be_a(Form)
      expect(form.name).to eq("English form")
    end

    context "when the mode is preview-draft" do
      let(:draft_form_document) { Api::V3::FormDocumentResource.new(name: "Draft English form") }

      before do
        incomplete_submission.mode = "preview-draft"
        allow(Api::V3::FormDocumentRepository).to receive(:find_draft)
                                                    .with(form_id: 1, language: :en)
                                                    .and_return(draft_form_document)
      end

      it "returns a Form built from the draft English form document" do
        form = incomplete_submission.form

        expect(form).to be_a(Form)
        expect(form.name).to eq("Draft English form")
        expect(Api::V3::FormDocumentRepository).not_to have_received(:find_by_version)
      end
    end
  end

  describe "#welsh_form" do
    let(:welsh_form_document) { Api::V3::FormDocumentResource.new(name: "Welsh form") }

    before do
      allow(Api::V3::FormDocumentRepository).to receive(:find_by_version)
                                                  .with(form_id: 1, version: 1, language: :cy)
                                                  .and_return(welsh_form_document)
    end

    it "returns a Form built from the Welsh form document for the saved version" do
      form = incomplete_submission.welsh_form

      expect(form).to be_a(Form)
      expect(form.name).to eq("Welsh form")
    end

    context "when the mode is preview-draft" do
      let(:draft_welsh_form_document) { Api::V3::FormDocumentResource.new(name: "Draft Welsh form") }

      before do
        incomplete_submission.mode = "preview-draft"
        allow(Api::V3::FormDocumentRepository).to receive(:find_draft)
                                                    .with(form_id: 1, language: :cy)
                                                    .and_return(draft_welsh_form_document)
      end

      it "returns a Form built from the draft Welsh form document" do
        form = incomplete_submission.welsh_form

        expect(form).to be_a(Form)
        expect(form.name).to eq("Draft Welsh form")
        expect(Api::V3::FormDocumentRepository).not_to have_received(:find_by_version)
      end
    end
  end
end
