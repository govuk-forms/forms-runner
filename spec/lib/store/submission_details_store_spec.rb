require "rails_helper"

RSpec.describe Store::SubmissionDetailsStore do
  subject(:submission_details_store) { described_class.new(store, form_id) }

  let(:store) { {} }
  let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:requested_email_confirmation) { true }
  let(:form_id) { 1 }
  let(:other_form_id) { 2 }
  let(:other_form_submission_details_store) { described_class.new(store, other_form_id) }

  before do
    allow(ReferenceNumberService).to receive(:generate).and_return(reference)
  end

  describe "#generate_submission_reference" do
    before do
      allow(ReferenceNumberService).to receive(:generate).and_return(reference)
    end

    it "stores and returns a new submission reference" do
      expect(submission_details_store.generate_submission_reference).to eq(reference)
      expect(submission_details_store.get_submission_reference).to eq(reference)
    end

    it "keeps the other submission details" do
      submission_details_store.save_requested_email_confirmation(requested_email_confirmation)

      submission_details_store.generate_submission_reference

      expect(submission_details_store.requested_email_confirmation?).to eq(requested_email_confirmation)
    end
  end

  describe "#save_requested_email_confirmation" do
    it "stores and returns the requested email confirmation flag" do
      submission_details_store.save_requested_email_confirmation(requested_email_confirmation)
      expect(submission_details_store.requested_email_confirmation?).to eq(requested_email_confirmation)
    end

    it "keeps the other submission details" do
      submission_details_store.generate_submission_reference

      submission_details_store.save_requested_email_confirmation(requested_email_confirmation)

      expect(submission_details_store.get_submission_reference).to eq(reference)
    end
  end

  describe "copy of answers details" do
    it "stores and retrieved the copy of answers preference" do
      submission_details_store.save_copy_of_answers_preference(true)
      expect(submission_details_store.wants_copy_of_answers?).to be true
    end

    it "stores and retrieves the copy of answers email address" do
      email_address = Faker::Internet.email
      submission_details_store.save_copy_of_answers_email_address(email_address)
      expect(submission_details_store.get_copy_of_answers_email_address).to eq(email_address)
    end

    it "returns nil when no copy of answers email address has been stored" do
      expect(submission_details_store.get_copy_of_answers_email_address).to be_nil
    end

    describe "#will_send_copy_of_answers?" do
      it "returns true when the user wants a copy and an email address is stored" do
        submission_details_store.save_copy_of_answers_preference(true)
        submission_details_store.save_copy_of_answers_email_address(Faker::Internet.email)
        expect(submission_details_store.will_send_copy_of_answers?).to be true
      end

      it "returns false when the user does not want a copy" do
        submission_details_store.save_copy_of_answers_preference(false)
        submission_details_store.save_copy_of_answers_email_address(Faker::Internet.email)
        expect(submission_details_store.will_send_copy_of_answers?).to be false
      end

      it "returns false when no email address is stored" do
        submission_details_store.save_copy_of_answers_preference(true)
        expect(submission_details_store.will_send_copy_of_answers?).to be false
      end
    end
  end

  describe "#clear_submission_details" do
    it "clears the submission details" do
      submission_details_store.generate_submission_reference
      submission_details_store.save_requested_email_confirmation(requested_email_confirmation)
      submission_details_store.save_copy_of_answers_preference(true)
      submission_details_store.save_copy_of_answers_email_address(Faker::Internet.email)

      submission_details_store.clear_submission_details

      expect(submission_details_store.get_submission_reference).to be_nil
      expect(submission_details_store.requested_email_confirmation?).to be_nil
      expect(submission_details_store.wants_copy_of_answers?).to be_nil
      expect(submission_details_store.get_copy_of_answers_email_address).to be_nil
    end
  end
end
