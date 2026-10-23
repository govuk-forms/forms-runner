require "rails_helper"

RSpec.describe LoadFormProgressService do
  subject(:service) { described_class.new(current_context:, user_id:) }

  let(:user_id) { "one-login-sub" }
  let(:form_document) { build(:form_document, form_id: 1, start_page: 1, steps: [build(:question_step, :with_text_settings, id: 1)]) }
  let(:form) { Form.new(form_document) }
  let(:current_context) { Flow::Context.new(form:, form_document:, store: {}) }

  describe "#load!" do
    context "when the user has saved progress for the form" do
      let(:saved_answers) { { "1" => { "text" => "a saved answer" } } }

      let!(:incomplete_submission) do
        IncompleteSubmission.create!(user_id:, form_id: form.id, answers: saved_answers, submission_reference: "SAVEDREF", locale: "cy")
      end

      it "returns the saved progress" do
        expect(service.load!).to eq(incomplete_submission)
      end

      it "loads the saved answers into the session" do
        service.load!

        expect(current_context.answers).to eq(saved_answers)
      end

      it "loads the submission reference into the session" do
        service.load!

        expect(current_context.get_submission_reference).to eq("SAVEDREF")
      end

      it "loads the locale the form was being filled in" do
        service.load!

        expect(current_context.submission_locale).to eq(:cy)
      end
    end

    context "when the user has no saved progress for the form" do
      it "returns nil" do
        expect(service.load!).to be_nil
      end
    end
  end
end
