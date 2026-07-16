require "rails_helper"

RSpec.describe SendS3SubmissionJob, type: :job do
  include ActiveJob::TestHelper

  let(:submission_created_at) { Time.utc(2022, 12, 14, 13, 0o0, 0o0) }
  let(:form_document) { build(:v2_form_document, name: "Form 1") }
  let(:submission) do
    create(:submission, form_document:, created_at: submission_created_at).tap do |submission|
      submission.deliveries.create!
    end
  end
  let(:delivery) { submission.deliveries.first }
  let(:journey) { instance_double(Flow::Journey) }
  let(:delivery_reference) { "s3-submission-key" }
  let(:s3_submission_service_spy) { instance_double(S3SubmissionService, submit: delivery_reference) }

  before do
    allow(submission).to receive(:journey).and_return(journey)
    allow(S3SubmissionService).to receive(:new).and_return(s3_submission_service_spy)
    allow(EventLogger).to receive(:log_form_event)
    allow(CloudWatchService).to receive(:record_submission_sent_metric)
    allow(CloudWatchService).to receive(:record_job_failure_metric)
  end

  context "when the job is processed with a Delivery argument" do
    it "submits via S3" do
      perform_enqueued_jobs do
        described_class.perform_later(delivery)
      end

      expect(S3SubmissionService).to have_received(:new).with(submission:)
      expect(s3_submission_service_spy).to have_received(:submit)
    end

    it "logs submission send timing event and metric" do
      perform_enqueued_jobs do
        described_class.perform_later(delivery)
      end

      expect(EventLogger).to have_received(:log_form_event).with(
        "submission_sent",
        hash_including(milliseconds_since_scheduled: satisfy { |value| value.is_a?(Integer) && value >= 0 }),
      )
      expect(CloudWatchService).to have_received(:record_submission_sent_metric).with(
        satisfy { |value| value.is_a?(Integer) && value >= 0 },
      )
    end

    it "updates the delivery last attempt time" do
      freeze_time do
        perform_enqueued_jobs do
          described_class.perform_later(delivery)
        end

        expect(delivery.reload.last_attempt_at).to eq(Time.zone.now)
      end
    end

    it "sets the delivery reference and last attempt time" do
      freeze_time do
        perform_enqueued_jobs do
          described_class.perform_later(delivery)
        end

        expect(delivery.reload.delivery_reference).to eq(delivery_reference)
        expect(delivery.reload.last_attempt_at).to eq(Time.zone.now)
      end
    end

    context "when the delivery is being retried" do
      let(:submission) do
        create(:submission, form_document:).tap do |submission|
          submission.deliveries.create!(delivery_reference: "old-ref",
                                        delivered_at: Time.zone.now,
                                        failed_at: Time.zone.now,
                                        failure_reason: "bounced")
        end
      end

      it "does not create a new delivery record" do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(delivery)
          end
        }.not_to change(submission.deliveries, :count)
      end

      it "updates the existing delivery record" do
        freeze_time do
          perform_enqueued_jobs do
            described_class.perform_later(delivery)
          end

          updated_delivery = delivery.reload
          expect(updated_delivery.delivery_reference).to eq(delivery_reference)
          expect(updated_delivery.last_attempt_at).to eq(Time.zone.now)
          expect(updated_delivery.delivered_at).to be_nil
          expect(updated_delivery.failed_at).to be_nil
          expect(updated_delivery.failure_reason).to be_nil
        end
      end
    end
  end

  context "when there is an error during processing" do
    before do
      allow(s3_submission_service_spy).to receive(:submit).and_raise(StandardError, "Test error")
    end

    it "raises an error" do
      expect { described_class.new.perform(delivery) }.to raise_error(StandardError, "Test error")
    end

    it "sends cloudwatch metric for failure" do
      described_class.new.perform(delivery)
      expect(CloudWatchService).to have_received(:record_job_failure_metric).with("SendS3SubmissionJob")
    rescue StandardError
      nil
    end
  end
end
