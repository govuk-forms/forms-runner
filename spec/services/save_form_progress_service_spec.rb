require "rails_helper"

RSpec.describe SaveFormProgressService do
  subject(:service) { described_class.new(current_context:, user_id:, mode:, email:) }

  let(:user_id) { "one-login-sub" }
  let(:mode) { Mode.new("preview-draft") }
  let(:email) { "test@example.com" }
  let(:form) { instance_double(Form, id: 1, version: 3) }
  let(:answers) { { "1" => { "text" => "an answer" } } }
  let(:submission_locale) { :cy }
  let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:submission_uuid) { SecureRandom.uuid }
  let(:current_context) { instance_double(Flow::Context, form:, answers:, submission_locale:, get_submission_reference: submission_reference, get_submission_uuid: submission_uuid) }

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
        submission_reference: submission_reference,
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
          .to raise_error(StandardError, "Failed to enqueue progress saved email for reference #{submission_reference}")
      end

      context "and there is an enqueue error" do
        let(:enqueue_error) { ActiveJob::EnqueueError.new("An error occurred enqueueing job") }

        it "includes the enqueue error message" do
          expect { service.save! }
            .to raise_error(StandardError, "Failed to enqueue progress saved email for reference #{submission_reference}: An error occurred enqueueing job")
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
  end
end
