require "rails_helper"

RSpec.describe Store::ConfirmationDetailsStore do
  subject(:confirmation_details_store) { described_class.new(store, form_id) }

  let(:store) { {} }
  let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:requested_email_confirmation) { true }
  let(:form_id) { 1 }
  let(:other_form_id) { 2 }
  let(:other_form_confirmation_details_store) { described_class.new(store, other_form_id) }

  describe "submission details" do
    it "stores and retrieves submission details" do
      confirmation_details_store.save_submission_details(reference, requested_email_confirmation)
      expect(confirmation_details_store.get_submission_reference).to eq(reference)
      expect(confirmation_details_store.requested_email_confirmation?).to eq(requested_email_confirmation)
    end

    it "stores the submission details for multiple forms without overwriting them" do
      confirmation_details_store.save_submission_details(reference, requested_email_confirmation)

      other_form_reference = Faker::Alphanumeric.alphanumeric(number: 8).upcase
      other_form_requested_email_confirmation = false
      other_form_confirmation_details_store.save_submission_details(other_form_reference, other_form_requested_email_confirmation)

      expect(confirmation_details_store.get_submission_reference).to eq(reference)
      expect(confirmation_details_store.requested_email_confirmation?).to eq(requested_email_confirmation)
      expect(other_form_confirmation_details_store.get_submission_reference).to eq(other_form_reference)
      expect(other_form_confirmation_details_store.requested_email_confirmation?).to eq(other_form_requested_email_confirmation)
    end
  end

  describe "copy of answers details" do
    it "stores and retrieved the copy of answers preference" do
      confirmation_details_store.save_copy_of_answers_preference(true)
      expect(confirmation_details_store.wants_copy_of_answers?).to be true
    end

    it "stores and retrieves the copy of answers email address" do
      email_address = Faker::Internet.email
      confirmation_details_store.save_copy_of_answers_email_address(email_address)
      expect(confirmation_details_store.get_copy_of_answers_email_address).to eq(email_address)
    end

    it "returns nil when no copy of answers email address has been stored" do
      expect(confirmation_details_store.get_copy_of_answers_email_address).to be_nil
    end
  end

  describe "#clear_submission_details" do
    it "clears the submission details" do
      confirmation_details_store.save_submission_details(reference, requested_email_confirmation)
      confirmation_details_store.save_copy_of_answers_preference(true)
      confirmation_details_store.save_copy_of_answers_email_address(Faker::Internet.email)

      confirmation_details_store.clear_submission_details

      expect(confirmation_details_store.get_submission_reference).to be_nil
      expect(confirmation_details_store.requested_email_confirmation?).to be_nil
      expect(confirmation_details_store.wants_copy_of_answers?).to be_nil
      expect(confirmation_details_store.get_copy_of_answers_email_address).to be_nil
    end
  end
end
