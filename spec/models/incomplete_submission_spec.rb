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
end
