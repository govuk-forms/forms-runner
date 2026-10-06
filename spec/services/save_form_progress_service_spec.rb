require "rails_helper"

RSpec.describe SaveFormProgressService do
  subject(:service) { described_class.new(current_context:, user_id:) }

  let(:user_id) { "one-login-sub" }
  let(:form) { instance_double(Form, id: 1, version: 3) }
  let(:answers) { { "1" => { "text" => "an answer" } } }
  let(:current_context) { instance_double(Flow::Context, form:, answers:) }

  describe "#save" do
    it "creates a saved answer from the current context" do
      expect { service.save }.to change(SavedAnswer, :count).by(1)

      saved = SavedAnswer.last
      expect(saved).to have_attributes(
        user_id:,
        form_id: form.id,
        form_version: form.version,
        answers:,
      )
    end

    context "when a saved answer already exists for the user and form" do
      let!(:existing) do
        SavedAnswer.create!(user_id:, form_id: form.id, form_version: 1, answers: { "old" => "answer" })
      end

      it "updates the existing row in place rather than creating a duplicate" do
        expect { service.save }.not_to change(SavedAnswer, :count)

        expect(existing.reload).to have_attributes(form_version: form.version, answers:)
      end
    end
  end
end
