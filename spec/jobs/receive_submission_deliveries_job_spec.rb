require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe ReceiveSubmissionDeliveriesJob, type: :job do
  include ActiveJob::TestHelper

  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:receipt_handle) { "delivery-receipt-handle" }
  let(:sqs_message_id) { "sqs-message-id" }
  let(:event_type) { "Delivery" }
  let(:sqs_message) { instance_double(Aws::SQS::Types::Message, message_id: sqs_message_id, receipt_handle:, body: sns_delivery_message_body) }
  let(:messages) { [] }
  let(:sns_message_timestamp) { "2025-05-09T10:25:43.972Z" }
  let(:ses_delivery_timestamp) { "2025-05-09T10:25:41.123Z" }
  let(:sns_delivery_message_body) { { "Message" => ses_delivery_message_body.to_json, "Timestamp" => sns_message_timestamp }.to_json }
  let(:ses_delivery_message_body) { { "mail" => { "messageId" => delivery_reference }, "eventType": event_type, "delivery": { "timestamp": ses_delivery_timestamp } } }
  let(:delivery_reference) { "delivery-reference" }
  let(:reference) { "submission-reference" }
  let!(:submission) { create :submission, :sent, delivery_reference:, reference:, created_at: Time.zone.parse("2025-05-09T10:25:35.001Z") }

  before do
    sts_client = instance_double(Aws::STS::Client)
    allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
    allow(sts_client).to receive(:get_caller_identity).and_return(OpenStruct.new(account: "123456789012"))

    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
    allow(sqs_client).to receive(:receive_message).and_return(OpenStruct.new(messages: messages), OpenStruct.new(messages: []))
    allow(sqs_client).to receive(:delete_message)

    allow(CloudWatchService).to receive(:record_job_started_metric)
  end

  describe "CloudWatch metrics" do
    let(:messages) { [sqs_message] }

    before do
      allow(CloudWatchService).to receive(:record_submission_delivery_latency_metric)
    end

    it "sends job started metric" do
      described_class.perform_now
      expect(CloudWatchService).to have_received(:record_job_started_metric).with("ReceiveSubmissionDeliveriesJob")
    end

    it "sends submission delivery latency metric" do
      described_class.perform_now
      # latency is ses_delivery_timestamp - submission.created_at
      expect(CloudWatchService).to have_received(:record_submission_delivery_latency_metric).with(6122, "Email")
    end

    context "when the delivery is a daily batch delivery" do
      let(:submission) { create :submission, :sent, delivery_reference: "something-else", created_at: Time.zone.parse("2025-05-09T10:25:35.001Z") }

      before do
        create :delivery, :daily, delivery_reference:, submissions: [submission], created_at: Time.zone.parse("2025-05-09T10:25:35.001Z")
      end

      it "does not send submission delivery latency metric" do
        described_class.perform_now
        expect(CloudWatchService).not_to have_received(:record_submission_delivery_latency_metric)
      end
    end

    context "when the delivery is a weekly batch delivery" do
      let(:submission) { create :submission, :sent, delivery_reference: "something-else", created_at: Time.zone.parse("2025-05-09T10:25:35.001Z") }

      before do
        create :delivery, :weekly, delivery_reference:, submissions: [submission], created_at: Time.zone.parse("2025-05-09T10:25:35.001Z")
      end

      it "does not send submission delivery latency metric" do
        described_class.perform_now
        expect(CloudWatchService).not_to have_received(:record_submission_delivery_latency_metric)
      end
    end
  end

  describe "processing delivery notifications" do
    let(:messages) { [sqs_message] }

    before do
      job = described_class.perform_later
      @job_id = job.job_id
      allow(CloudWatchService).to receive(:record_submission_delivery_latency_metric)
    end

    it "updates the delivery delivered_at timestamp" do
      perform_enqueued_jobs
      expect(submission.deliveries.first.reload.delivered_at).to eq ses_delivery_timestamp
    end

    it "logs form event with correct details", :capture_logging do
      perform_enqueued_jobs

      expect(log_lines).to include(hash_including(
                                     "level" => "INFO",
                                     "message" => "Form event",
                                     "event" => "form_submission_delivered",
                                     "form_id" => submission.form_id,
                                     "submission_reference" => reference,
                                     "preview" => "false",
                                     "delivered_at" => Time.zone.parse(ses_delivery_timestamp),
                                     "delivery_latency" => 6122,
                                     "sns_message_timestamp" => sns_message_timestamp,
                                     "job_id" => @job_id,
                                     "job_class" => "ReceiveSubmissionDeliveriesJob",
                                   ))
    end

    context "when the delivery is a daily batch delivery" do
      let!(:submission) { create :submission, :sent, delivery_reference: "something-else" }
      let!(:delivery) { create(:delivery, :daily_scheduled_delivery, delivery_reference:, submissions: [submission], created_at: Time.zone.parse("2025-05-09T10:25:35.001Z")) }

      it "logs form event with batch delivery details", :capture_logging do
        perform_enqueued_jobs

        expect(log_lines).to include(hash_including(
                                       "level" => "INFO",
                                       "message" => "Form event",
                                       "event" => "form_submission_batch_delivered",
                                       "form_id" => submission.form_id,
                                       "form_name" => submission.form.name,
                                       "delivery_reference" => delivery_reference,
                                       "delivery_id" => delivery.id,
                                       "delivery_schedule" => "daily",
                                       "batch_begin_at" => delivery.batch_begin_at,
                                       "preview" => "false",
                                       "sns_message_timestamp" => sns_message_timestamp,
                                       "job_id" => @job_id,
                                       "job_class" => "ReceiveSubmissionDeliveriesJob",
                                     ))
      end
    end

    context "when the delivery is a weekly batch delivery" do
      let!(:submission) { create :submission, :sent, delivery_reference: "something-else" }
      let!(:delivery) { create(:delivery, :weekly_scheduled_delivery, delivery_reference:, submissions: [submission], created_at: Time.zone.parse("2025-05-09T10:25:35.001Z")) }

      it "logs form event with batch delivery details", :capture_logging do
        perform_enqueued_jobs

        expect(log_lines).to include(hash_including(
                                       "level" => "INFO",
                                       "message" => "Form event",
                                       "event" => "form_submission_batch_delivered",
                                       "form_id" => submission.form_id,
                                       "form_name" => submission.form.name,
                                       "delivery_reference" => delivery_reference,
                                       "delivery_id" => delivery.id,
                                       "delivery_schedule" => "weekly",
                                       "batch_begin_at" => delivery.batch_begin_at,
                                       "preview" => "false",
                                       "sns_message_timestamp" => sns_message_timestamp,
                                       "job_id" => @job_id,
                                       "job_class" => "ReceiveSubmissionDeliveriesJob",
                                     ))
      end
    end
  end

  describe "handling unexpected event types" do
    let(:event_type) { "Some other event type" }
    let(:messages) { [sqs_message] }

    it "raises an error with the unexpected event type" do
      allow(Sentry).to receive(:capture_exception)

      described_class.perform_now

      expect(Sentry).to have_received(:capture_exception) do |error|
        expect(error.message).to eq("Unexpected event type:#{event_type}")
      end
    end
  end

  context "when the delivery is not found" do
    let(:messages) { [sqs_message] }
    let(:submission) { nil }

    it "captures the error and does not delete the message" do
      allow(Sentry).to receive(:capture_exception)

      described_class.perform_now

      expect(Sentry).to have_received(:capture_exception).with(an_instance_of(ActiveRecord::RecordNotFound))
      expect(sqs_client).not_to have_received(:delete_message)
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
