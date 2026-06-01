require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe ReceiveConfirmationBouncesAndComplaintsJob do
  include ActiveJob::TestHelper

  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:aws_account_id) { "123456789012" }
  let(:queue_name) { "bounces-queue" }
  let(:receipt_handle) { "bounce-receipt-handle" }
  let(:sqs_message_id) { "sqs-message-id" }
  let(:sqs_message) { instance_double(Aws::SQS::Types::Message, message_id: sqs_message_id, receipt_handle:, body: sns_message_body) }
  let(:messages) { [] }
  let(:message_id) { Faker::Alphanumeric.alphanumeric }

  let(:sns_message_timestamp) { "2025-05-09T10:25:43.972Z" }
  let(:sns_message_body) { { "Message" => ses_message_body.to_json, "Timestamp" => sns_message_timestamp }.to_json }
  let(:event_type) { "Bounce" }
  let(:bounce_timestamp) { "2023-01-01T12:00:00Z" }
  let(:ses_message_body) do
    {
      "mail" => { "messageId" => message_id },
      "eventType" => event_type,
      "bounce" => bounce,
    }
  end
  let(:bounce) do
    {
      "bounceType" => "Permanent",
      "bounceSubType" => "General",
      "reportingMTA" => "Some MTA",
      "feedbackId" => "feedback-id",
      "timestamp" => bounce_timestamp,
    }
  end

  before do
    allow(Settings.aws).to receive(:confirmation_email_bounces_and_complaints_sqs_queue_name).and_return(queue_name)

    sts_client = instance_double(Aws::STS::Client)
    allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
    allow(sts_client).to receive(:get_caller_identity).and_return(OpenStruct.new(account: aws_account_id))

    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
    allow(sqs_client).to receive(:receive_message).and_return(OpenStruct.new(messages: messages), OpenStruct.new(messages: []))
    allow(sqs_client).to receive(:delete_message)

    allow(CloudWatchService).to receive(:record_job_started_metric)

    job = described_class.perform_later
    @job_id = job.job_id
  end

  it "calls SQS with the expected queue URL" do
    perform_enqueued_jobs
    expect(sqs_client).to have_received(:receive_message).with(
      hash_including(queue_url: "https://sqs.eu-west-2.amazonaws.com/#{aws_account_id}/#{queue_name}"),
    ).once
  end

  it "sends job started metric" do
    perform_enqueued_jobs
    expect(CloudWatchService).to have_received(:record_job_started_metric).with("ReceiveConfirmationBouncesAndComplaintsJob")
  end

  context "when handling a bounce", :capture_logging do
    let(:messages) { [sqs_message] }

    it "logs with details of the bounce" do
      perform_enqueued_jobs

      expect(log_lines).to include(hash_including(
                                     "level" => "INFO",
                                     "message" => "Bounce notification received for confirmation email",
                                     "job_id" => @job_id,
                                     "job_class" => "ReceiveConfirmationBouncesAndComplaintsJob",
                                     "confirmation_email_id" => message_id,
                                     "ses_bounce" => {
                                       "bounce_type" => "Permanent",
                                       "bounce_sub_type" => "General",
                                       "reporting_mta" => "Some MTA",
                                       "timestamp" => bounce_timestamp,
                                       "feedback_id" => "feedback-id",
                                     },
                                   ))
    end
  end

  context "when handling a complaint", :capture_logging do
    let(:event_type) { "Complaint" }
    let(:messages) { [sqs_message] }

    it "logs with details of the complaint" do
      perform_enqueued_jobs

      expect(log_lines).to include(hash_including(
                                     "level" => "INFO",
                                     "message" => "Complaint notification received for confirmation email",
                                     "job_id" => @job_id,
                                     "job_class" => "ReceiveConfirmationBouncesAndComplaintsJob",
                                     "confirmation_email_id" => message_id,
                                   ))
    end
  end

  describe "handling unexpected event types" do
    let(:event_type) { "Some other event type" }
    let(:messages) { [sqs_message] }

    it "raises an error with the unexpected event type" do
      allow(Sentry).to receive(:capture_exception)

      perform_enqueued_jobs

      expect(Sentry).to have_received(:capture_exception) do |error|
        expect(error.message).to eq("Unexpected event type:#{event_type}")
      end
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
