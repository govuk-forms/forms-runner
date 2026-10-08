require "rails_helper"

RSpec.describe SavedAnswer, type: :model do
  subject(:saved_answer) do
    described_class.new(user_id: "one-login-sub", form_id: 1, form_version: 1, answers: {})
  end

  describe "validations" do
    it "is valid with a user_id and form_id" do
      expect(saved_answer).to be_valid
    end

    context "without a user_id" do
      before { saved_answer.user_id = nil }

      it "is invalid" do
        expect(saved_answer).not_to be_valid
        expect(saved_answer.errors[:user_id]).to include("can't be blank")
      end
    end

    context "without a form_id" do
      before { saved_answer.form_id = nil }

      it "is invalid" do
        expect(saved_answer).not_to be_valid
        expect(saved_answer.errors[:form_id]).to include("can't be blank")
      end
    end
  end
end
