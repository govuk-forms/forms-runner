require "rails_helper"

RSpec.describe Submission, type: :model do
  describe "scopes" do
    describe ".for_form_and_mode" do
      let(:form_id) { 101 }
      let!(:form_and_mode_submission) { create(:submission, form_id:, mode: "form") }

      before do
        create(:submission, form_id: 5, mode: "form")
        create(:submission, form_id:, mode: "preview-live")
      end

      it "returns only submissions for the given form and mode" do
        submissions = described_class.for_form_and_mode(form_id, "form")
        expect(submissions.size).to eq(1)
        expect(submissions).to contain_exactly(form_and_mode_submission)
      end
    end

    describe ".on_day" do
      context "when the date is around the start of BST" do
        # London local date 2025-03-29 => UTC 2025-03-29 00:00:00..2025-03-29 23:59:59
        let!(:start_of_gmt_day_submission) { create(:submission, created_at: Time.utc(2025, 3, 29, 0, 0, 0)) }
        let!(:end_of_gmt_day_submission) { create(:submission, created_at: Time.utc(2025, 3, 29, 23, 59, 59)) }

        # London local date 2025-03-30 => UTC 2025-03-30 00:00:00..2025-03-30 22:59:59
        let!(:start_of_change_day_submission) { create(:submission, created_at: Time.utc(2025, 3, 30, 0, 0, 0)) }
        let!(:end_of_change_day_submission) { create(:submission, created_at: Time.utc(2025, 3, 30, 22, 59, 59)) }

        # London local date 2025-03-31 => UTC 2025-03-30 23:00:00..2025-03-31 22:59:59
        let!(:start_of_bst_day_submission) { create(:submission, created_at: Time.utc(2025, 3, 30, 23, 0, 0)) }
        let!(:end_of_bst_day_submission) { create(:submission, created_at: Time.utc(2025, 3, 31, 22, 59, 59)) }
        let(:date) { Date.new(2022, 6, 1) }

        it "returns submissions on the day before the clocks change" do
          submissions = described_class.on_day(Date.new(2025, 3, 29))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(start_of_gmt_day_submission, end_of_gmt_day_submission)
        end

        it "returns submissions on the day of the clocks change" do
          submissions = described_class.on_day(Date.new(2025, 3, 30))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(start_of_change_day_submission, end_of_change_day_submission)
        end

        it "returns submissions on the day after the clocks change" do
          submissions = described_class.on_day(Date.new(2025, 3, 31))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(start_of_bst_day_submission, end_of_bst_day_submission)
        end
      end

      context "when the date is around the end of BST" do
        # London local date 2025-10-25 => UTC 2025-10-24 23:00:00..2025-10-25 22:59:59
        let!(:start_of_bst_day_submission) { create(:submission, created_at: Time.utc(2025, 10, 24, 23, 0, 0)) }
        let!(:end_of_bst_day_submission) { create(:submission, created_at: Time.utc(2025, 10, 25, 22, 59, 59)) }

        # London local date 2025-10-26 => UTC 2025-10-25 23:00:00..2025-10-26 23:59:59
        let!(:start_of_change_day_submission) { create(:submission, created_at: Time.utc(2025, 10, 25, 23, 0, 0)) }
        let!(:end_of_change_day_submission) { create(:submission, created_at: Time.utc(2025, 10, 26, 23, 59, 59)) }

        # London local date 2025-10-27 => UTC 2025-10-27 00:00:00..2025-10-27 23:59:59
        let!(:start_of_gmt_day_submission) { create(:submission, created_at: Time.utc(2025, 10, 27, 0, 0, 0)) }
        let!(:end_of_gmt_day_submission) { create(:submission, created_at: Time.utc(2025, 10, 27, 23, 59, 59)) }

        it "returns submissions on the day before the clocks change" do
          submissions = described_class.on_day(Date.new(2025, 10, 25))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(start_of_bst_day_submission, end_of_bst_day_submission)
        end

        it "returns submissions on the day of the clocks change" do
          submissions = described_class.on_day(Date.new(2025, 10, 26))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(start_of_change_day_submission, end_of_change_day_submission)
        end

        it "returns submissions on the day after the clocks change" do
          submissions = described_class.on_day(Date.new(2025, 10, 27))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(start_of_gmt_day_submission, end_of_gmt_day_submission)
        end
      end
    end

    describe ".in_week" do
      context "when the date is around the start of BST" do
        let!(:gmt_monday_submission) { create(:submission, created_at: Time.utc(2025, 3, 17, 0, 0, 0)) }
        let!(:gmt_sunday_submission) { create(:submission, created_at: Time.utc(2025, 3, 23, 23, 59, 59)) }

        let!(:clock_change_week_monday_submission) { create(:submission, created_at: Time.utc(2025, 3, 24, 0, 0, 0)) }
        let!(:clock_change_week_sunday_submission) { create(:submission, created_at: Time.utc(2025, 3, 30, 22, 59, 59)) }

        let!(:bst_monday_submission) { create(:submission, created_at: Time.utc(2025, 3, 30, 23, 0, 0)) }
        let!(:bst_sunday_submission) { create(:submission, created_at: Time.utc(2025, 4, 6, 22, 59, 59)) }

        it "returns the submissions for the week before the clocks change" do
          submissions = described_class.in_week(Time.utc(2025, 3, 17, 0, 0, 0))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(gmt_monday_submission, gmt_sunday_submission)
        end

        it "returns the submissions for the week of the clocks change" do
          submissions = described_class.in_week(Time.utc(2025, 3, 24, 0, 0, 0))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(clock_change_week_monday_submission, clock_change_week_sunday_submission)
        end

        it "returns the submissions for the week after the clocks change" do
          submissions = described_class.in_week(Time.utc(2025, 3, 30, 23, 0, 0))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(bst_monday_submission, bst_sunday_submission)
        end
      end

      context "when the date is around the end of BST" do
        let!(:bst_monday_submission) { create(:submission, created_at: Time.utc(2025, 10, 12, 23, 0, 0)) }
        let!(:bst_sunday_submission) { create(:submission, created_at: Time.utc(2025, 10, 19, 22, 59, 59)) }

        let!(:clock_change_week_monday_submission) { create(:submission, created_at: Time.utc(2025, 10, 19, 23, 0, 0)) }
        let!(:clock_change_week_sunday_submission) { create(:submission, created_at: Time.utc(2025, 10, 26, 23, 59, 59)) }

        let!(:gmt_monday_submission) { create(:submission, created_at: Time.utc(2025, 10, 27, 0, 0, 0)) }
        let!(:gmt_sunday_submission) { create(:submission, created_at: Time.utc(2025, 11, 2, 23, 59, 59)) }

        it "returns the submissions for the week before the clocks change" do
          submissions = described_class.in_week(Time.utc(2025, 10, 13, 23, 0, 0))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(bst_monday_submission, bst_sunday_submission)
        end

        it "returns the submissions for the week of the clocks change" do
          submissions = described_class.in_week(Time.utc(2025, 10, 20, 23, 0, 0))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(clock_change_week_monday_submission, clock_change_week_sunday_submission)
        end

        it "returns the submissions for the week after the clocks change" do
          submissions = described_class.in_week(Time.utc(2025, 10, 27, 0, 0, 0))
          expect(submissions.size).to eq(2)
          expect(submissions).to contain_exactly(gmt_monday_submission, gmt_sunday_submission)
        end
      end
    end

    describe ".ordered_by_form_version_and_date" do
      let(:first_form_version) { build :v2_form_document, updated_at: Time.utc(2022, 6, 1, 12, 0, 0) }
      let(:second_form_version) { build :v2_form_document, updated_at: Time.utc(2022, 12, 1, 12, 0, 0) }

      before do
        create :submission, form_document: second_form_version, created_at: Time.utc(2022, 12, 1, 21, 0, 0), reference: "fourth_submission"
        create :submission, form_document: first_form_version, created_at: Time.utc(2022, 12, 1, 15, 0, 0), reference: "third_submission"
        create :submission, form_document: second_form_version, created_at: Time.utc(2022, 12, 1, 13, 0, 0), reference: "second_submission"
        create :submission, form_document: first_form_version, created_at: Time.utc(2022, 12, 1, 9, 0, 0), reference: "first_submission"
      end

      it "returns the submissions in order" do
        expect(described_class.all.ordered_by_form_version_and_date.pluck(:reference)).to eq(%w[first_submission third_submission second_submission fourth_submission])
      end
    end
  end

  describe "#sent?" do
    context "when the submission is sent" do
      let(:submission) { create :submission, :sent }

      it "returns true" do
        expect(described_class).to be_sent(submission.reference)
      end
    end

    context "when the submission is not sent" do
      let(:submission) { create :submission, deliveries: [create(:delivery, :not_sent)] }

      it "returns false" do
        expect(described_class).not_to be_sent(submission.reference)
      end
    end

    context "when there is no submission" do
      it "returns false" do
        expect(described_class).not_to be_sent("999")
      end
    end
  end

  describe "#submission_time" do
    subject(:submission) { described_class.create!(created_at: created_at) }

    context "with a time in BST" do
      let(:created_at) { Time.utc(2022, 9, 14, 7, 0, 0) }

      it "has BST timezone" do
        expect(submission.submission_time.zone).to eq("BST")
      end

      it "returns the local time when stringified" do
        expect(submission.submission_time.strftime("%-d %B %Y - %l:%M%P")).to eq("14 September 2022 -  8:00am")
      end
    end

    context "with a time in GMT" do
      let(:created_at) { Time.utc(2022, 12, 14, 13, 0, 0) }

      it "has GMT timezone" do
        expect(submission.submission_time.zone).to eq("GMT")
      end

      it "returns the local time when stringified" do
        expect(submission.submission_time.strftime("%-d %B %Y - %l:%M%P")).to eq("14 December 2022 -  1:00pm")
      end
    end
  end

  describe "#single_submission_delivery" do
    context "when there is a single delivery with 'immediate' delivery_schedule" do
      let(:submission) { create :submission }
      let!(:delivery) { submission.deliveries.create!(delivery_schedule: :immediate) }

      before do
        submission.deliveries.create!(delivery_schedule: :daily)
      end

      it "returns the delivery without a batch frequency" do
        expect(submission.single_submission_delivery).to eq(delivery)
      end
    end

    context "when there are multiple deliveries with 'immediate' delivery_schedule" do
      let(:submission) { create :submission }

      before do
        submission.deliveries.create!(delivery_schedule: :immediate)
        submission.deliveries.create!(delivery_schedule: :immediate)
      end

      it "raises an error" do
        expect {
          submission.single_submission_delivery
        }.to raise_error(ActiveRecord::SoleRecordExceeded)
      end
    end

    context "when there is a single delivery with 'daily' delivery_schedule" do
      let(:submission) { create :submission }

      before do
        submission.deliveries.create!(delivery_schedule: :daily)
      end

      it "raises an error" do
        expect {
          submission.single_submission_delivery
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "submission_locale" do
    subject(:submission) { create :submission }

    it "returns the submission locale" do
      expect(submission.submission_locale).to eq("en")
    end
  end

  describe "destroy" do
    subject(:submission) { create :submission }

    context "when there is a delivery only associated to this submission" do
      let!(:delivery) { submission.deliveries.create!(delivery_reference: "message-id") }

      it "destroys the SubmissionDelivery join record" do
        expect {
          submission.destroy
        }.to change(SubmissionDelivery, :count).by(-1)
      end

      it "destroys associated delivery record" do
        submission.destroy!
        expect(Delivery.exists?(delivery.id)).to be false
      end
    end

    context "when there is a delivery associated to multiple submissions" do
      let(:delivery) { create :delivery, delivery_reference: "message-id" }

      before do
        other_submission = create :submission
        SubmissionDelivery.create!(submission: submission, delivery: delivery)
        SubmissionDelivery.create!(submission: other_submission, delivery: delivery)
      end

      it "destroys the SubmissionDelivery join record" do
        expect {
          submission.destroy
        }.to change(SubmissionDelivery, :count).by(-1)
      end

      it "does not destroy associated delivery record" do
        submission.destroy!
        expect(Delivery.exists?(delivery.id)).to be true
      end
    end
  end
end
