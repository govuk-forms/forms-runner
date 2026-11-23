require "rails_helper"

RSpec.describe LoadFormProgressService do
  subject(:service) { described_class.new(current_context:, user_id:, mode:) }

  let(:user_id) { "one-login-sub" }
  let(:mode) { Mode.new("form") }
  let(:form_document) { build(:form_document, form_id: 1, start_page: 1, steps: [build(:question_step, :with_text_settings, id: 1)]) }
  let(:form) { Form.new(form_document) }
  let(:current_context) { Flow::Context.new(form:, form_document:, store: {}) }

  describe "#load!" do
    context "when the user has saved progress for the form" do
      let(:saved_answers) { { "1" => { "text" => "a saved answer" } } }

      let!(:incomplete_submission) do
        create(:incomplete_submission, user_id:, form_id: form.id, answers: saved_answers, submission_uuid: "saved-uuid", locale: "cy")
      end

      it "returns the saved progress" do
        expect(service.load!).to eq(incomplete_submission)
      end

      it "loads the saved answers into the session" do
        service.load!

        expect(current_context.answers).to eq(saved_answers)
      end

      it "loads the submission uuid into the session" do
        service.load!

        expect(current_context.get_submission_uuid).to eq("saved-uuid")
      end

      it "loads the locale the form was being filled in" do
        service.load!

        expect(current_context.submission_locale).to eq(:cy)
      end

      it "logs the incomplete submission loaded event with the saved submission uuid" do
        logged_submission_uuid = nil
        allow(EventLogger).to receive(:log_form_event) do
          logged_submission_uuid = CurrentRequestLoggingAttributes.submission_uuid
        end

        service.load!

        expect(EventLogger).to have_received(:log_form_event).with("incomplete_submission_loaded").once
        expect(logged_submission_uuid).to eq("saved-uuid")
      end
    end

    context "when the saved answers include uploaded files" do
      let(:file_upload_s3_service) { instance_double(Question::FileUploadS3Service) }
      let(:existing_file_answer) { { "uploaded_file_key" => "existing-key", "original_filename" => "a.png" } }
      let(:missing_file_answer) { { "uploaded_file_key" => "missing-key", "original_filename" => "b.png" } }
      let(:skipped_optional_file_answer) { { "original_filename" => "" } }
      let(:text_answer) { { "text" => "a saved answer" } }

      before do
        allow(Question::FileUploadS3Service).to receive(:new).and_return(file_upload_s3_service)
        allow(file_upload_s3_service).to receive(:file_exists?).with("existing-key").and_return(true)
        allow(file_upload_s3_service).to receive(:file_exists?).with("missing-key").and_return(false)
        allow(FileUploadLogger).to receive(:log_s3_operation)

        create(:incomplete_submission, user_id:, form_id: form.id, answers: {
          "1" => text_answer,
          "2" => existing_file_answer,
          "3" => missing_file_answer,
          "4" => skipped_optional_file_answer,
        })
      end

      it "only loads file upload answers whose file still exists in S3" do
        service.load!

        expect(current_context.answers).to eq({
          "1" => text_answer,
          "2" => existing_file_answer,
          "4" => skipped_optional_file_answer,
        })
      end

      it "only checks S3 for answers with an uploaded file" do
        service.load!

        expect(file_upload_s3_service).to have_received(:file_exists?).twice
      end

      it "logs that the missing file's answer was not loaded" do
        service.load!

        expect(FileUploadLogger).to have_received(:log_s3_operation)
          .with("missing-key", "Uploaded file for saved answer no longer exists in S3, not loading answer")
      end
    end

    context "when the user has no saved progress for the form" do
      it "returns nil" do
        expect(service.load!).to be_nil
      end

      it "does not log an event" do
        allow(EventLogger).to receive(:log_form_event)

        service.load!

        expect(EventLogger).not_to have_received(:log_form_event)
      end
    end

    context "when the user only has saved progress for the form in a different mode" do
      before do
        create(:incomplete_submission, user_id:, form_id: form.id, answers: { "1" => { "text" => "a draft answer" } }, mode: "preview-draft")
      end

      it "returns nil" do
        expect(service.load!).to be_nil
      end

      it "does not load the answers into the session" do
        service.load!

        expect(current_context.answers).to be_nil
      end
    end
  end
end
