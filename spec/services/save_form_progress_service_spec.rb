require "rails_helper"

RSpec.describe SaveFormProgressService do
  subject(:service) { described_class.new(current_context:, user_id:, mode:, email:) }

  let(:user_id) { "one-login-sub" }
  let(:mode) { Mode.new("preview-draft") }
  let(:email) { "test@example.com" }
  let(:form) { instance_double(Form, id: 1, version: 3) }
  let(:answers) { { "1" => { "text" => "an answer" } } }
  let(:submission_locale) { :cy }
  let(:submission_uuid) { SecureRandom.uuid }
  let(:current_context) { instance_double(Flow::Context, form:, journey:, answers:, submission_locale:, get_submission_uuid: submission_uuid) }
  let(:journey) { instance_double(Flow::Journey, completed_file_upload_questions: [file_question]) }
  let(:file_question) { instance_double(Question::File, extend_life: nil) }

  describe "#save" do
    it "creates a saved answer from the current context" do
      expect { service.save! }.to change(IncompleteSubmission, :count).by(1)

      saved = IncompleteSubmission.last
      expect(saved).to have_attributes(
        user_id:,
        form_id: form.id,
        form_version: form.version,
        answers:,
        locale: "cy",
        mode: "preview-draft",
        submission_uuid: submission_uuid,
      )
    end

    it "enqueues the progress saved email for the saved answer" do
      allow(SendProgressSavedEmailJob).to receive(:perform_later)

      service.save!

      expect(SendProgressSavedEmailJob).to have_received(:perform_later).with(incomplete_submission: IncompleteSubmission.last, email_address: email)
    end

    context "when the email job fails to enqueue" do
      let(:enqueue_error) { nil }

      before do
        allow(SendProgressSavedEmailJob).to receive(:perform_later)
          .and_yield(instance_double(SendProgressSavedEmailJob, successfully_enqueued?: false, enqueue_error:))
      end

      it "raises an error" do
        expect { service.save! }
          .to raise_error(StandardError, "Failed to enqueue progress saved email for submission #{submission_uuid}")
      end

      context "and there is an enqueue error" do
        let(:enqueue_error) { ActiveJob::EnqueueError.new("An error occurred enqueueing job") }

        it "includes the enqueue error message" do
          expect { service.save! }
            .to raise_error(StandardError, "Failed to enqueue progress saved email for submission #{submission_uuid}: An error occurred enqueueing job")
        end
      end
    end

    context "when a saved answer already exists for the user and form" do
      let!(:existing) do
        IncompleteSubmission.create!(user_id:, form_id: form.id, form_version: 1, answers: { "old" => "answer" }, mode: "preview-draft", submission_uuid: SecureRandom.uuid)
      end

      it "updates the existing row in place rather than creating a duplicate" do
        expect { service.save! }.not_to change(IncompleteSubmission, :count)

        expect(existing.reload).to have_attributes(form_version: form.version, answers:)
      end
    end

    context "when the existing saved answer has not changed but the user clicks save" do
      let!(:existing) do
        IncompleteSubmission.create!(
          user_id:,
          form_id: form.id,
          form_version: form.version,
          answers:,
          locale: "cy",
          mode: "preview-draft",
          submission_uuid:,
          updated_at: 1.day.ago,
        )
      end

      it "updates the saved answer timestamp" do
        expect { service.save! }.to(change { existing.reload.updated_at })
      end
    end

    context "when a concurrent save inserts a conflicting row after we have loaded the existing one" do
      def insert_competing_row_after_load(**attributes)
        allow(IncompleteSubmission).to receive(:find_or_initialize_by).and_wrap_original do |original, *args, **kwargs|
          original.call(*args, **kwargs).tap do
            IncompleteSubmission.create!(form_version: 1, answers: { "old" => "answer" }, **attributes)
          end
        end
      end

      context "and it uses the same submission_uuid" do
        let(:new_uuid) { SecureRandom.uuid }

        before do
          insert_competing_row_after_load(user_id: "other-sub", form_id: form.id, mode: "preview-draft", submission_uuid:)

          allow(current_context).to receive(:generate_submission_uuid) do
            allow(current_context).to receive(:get_submission_uuid).and_return(new_uuid)
            new_uuid
          end
          allow(Rails.logger).to receive(:info)
        end

        it "saves a new row with a regenerated submission_uuid" do
          expect { service.save! }.to change(IncompleteSubmission, :count).by(2)

          expect(IncompleteSubmission.find_by(user_id:)).to have_attributes(submission_uuid: new_uuid, answers:)
        end

        it "leaves the competing row unchanged" do
          service.save!

          expect(IncompleteSubmission.find_by(user_id: "other-sub")).to have_attributes(answers: { "old" => "answer" }, submission_uuid:)
        end

        it "logs that the submission_uuid was regenerated" do
          service.save!

          expect(Rails.logger).to have_received(:info).with(/Regenerated submission_uuid/, { previous_submission_uuid: submission_uuid })
        end
      end

      context "and it is for the same user, form and mode" do
        before do
          insert_competing_row_after_load(user_id:, form_id: form.id, mode: "preview-draft", submission_uuid: SecureRandom.uuid)
        end

        it "does not regenerate the submission_uuid and raises the error" do
          expect { service.save! }.to raise_error(ActiveRecord::RecordInvalid, /Form has already been taken/)
        end
      end
    end

    context "when a saved answer exists for the user and form in a different mode" do
      let!(:other_mode) do
        IncompleteSubmission.create!(user_id:, form_id: form.id, form_version: 1, answers: { "old" => "answer" }, mode: "form", submission_uuid: SecureRandom.uuid)
      end

      it "creates a separate row for this mode" do
        expect { service.save! }.to change(IncompleteSubmission, :count).by(1)

        expect(IncompleteSubmission.find_by(user_id:, form_id: form.id, mode: "preview-draft").answers).to eq answers
      end

      it "leaves the other mode's saved answers unchanged" do
        service.save!

        expect(other_mode.reload.answers).to eq({ "old" => "answer" })
      end
    end

    context "when there is an existing uploaded file that has been updated" do
      it "extends the life of the file" do
        service.save!

        expect(file_question).to have_received(:extend_life)
      end
    end
  end
end
