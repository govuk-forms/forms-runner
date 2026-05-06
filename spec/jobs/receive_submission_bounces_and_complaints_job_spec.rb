require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe ReceiveSubmissionBouncesAndComplaintsJob, type: :job do
  include ActiveJob::TestHelper

  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:receipt_handle) { "bounce-receipt-handle" }
  let(:sqs_message_id) { "sqs-message-id" }
  let(:sqs_message) { instance_double(Aws::SQS::Types::Message, message_id: sqs_message_id, receipt_handle:, body: sns_message_body) }
  let(:messages) { [] }

  let(:sns_message_timestamp) { "2025-05-09T10:25:43.972Z" }
  let(:sns_message_body) { { "Message" => ses_message_body.to_json, "Timestamp" => sns_message_timestamp }.to_json }
  let(:event_type) { "Bounce" }
  let(:bounce_timestamp) { "2023-01-01T12:00:00Z" }
  let(:ses_message_body) do
    {
      "mail" => { "messageId" => delivery_reference },
      "eventType" => event_type,
      "bounce" => bounce,
    }
  end
  let(:bounce) do
    {
      "bounceType" => "Permanent",
      "bounceSubType" => "General",
      "bouncedRecipients" => bounced_recipients,
      "timestamp" => bounce_timestamp,
    }
  end
  let(:bounced_recipients) { [{ "emailAddress" => "bounce@example.com" }] }

  let(:delivery_reference) { "delivery-reference" }
  let(:reference) { "submission-reference" }
  let(:mode) { "form" }
  let(:submission) { create :submission, reference:, mode: }
  let!(:delivery) { create :delivery, delivery_reference:, submissions: [submission] }

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

    it "sends job started metric" do
      described_class.perform_now
      expect(CloudWatchService).to have_received(:record_job_started_metric).with("ReceiveSubmissionBouncesAndComplaintsJob")
    end
  end

  context "when handling submission delivery bounces", :capture_logging do
    describe "processing bounce notifications" do
      let(:messages) { [sqs_message] }

      before do
        job = described_class.perform_later
        @job_id = job.job_id
      end

      context "when it is for a live submission" do
        it "updates the delivery record with the bounce details" do
          perform_enqueued_jobs

          expect(delivery.reload.failed_at).to eq(Time.zone.parse(bounce_timestamp))
          expect(delivery.reload.failure_reason).to eq("bounced")
          expect(delivery.reload.failure_details).to eq(bounce)
        end

        it "logs form event with correct details" do
          perform_enqueued_jobs

          expect(log_lines).to include(hash_including(
                                         "level" => "INFO",
                                         "message" => "Form event",
                                         "event" => "form_submission_bounced",
                                         "form_id" => submission.form_id,
                                         "submission_reference" => reference,
                                         "preview" => "false",
                                         "delivery_reference" => delivery_reference,
                                         "delivery_id" => delivery.id,
                                         "sqs_message_id" => sqs_message_id,
                                         "sns_message_timestamp" => sns_message_timestamp,
                                         "job_id" => @job_id,
                                         "job_class" => "ReceiveSubmissionBouncesAndComplaintsJob",
                                         "ses_bounce" => hash_including(
                                           "bounce_type" => "Permanent",
                                           "bounce_sub_type" => "General",
                                           "bounced_recipients" => [
                                             hash_including(
                                               "email_address" => "bounce@example.com",
                                             ),
                                           ],
                                         ),
                                       ))
        end

        it "alerts to Sentry that there was a bounced delivery" do
          allow(Sentry).to receive(:capture_message)
          perform_enqueued_jobs
          expect(Sentry).to have_received(:capture_message).with(
            a_string_including("Submission email bounced for form #{submission.form_id} - ReceiveSubmissionBouncesAndComplaintsJob"),
            fingerprint: ["{{ default }}", submission.form_id],
            extra: hash_including(
              ses_bounce: hash_including(
                bounce_type: "Permanent",
                bounce_sub_type: "General",
              ),
            ),
          )
        end

        it "does not include bounced recipients in the Sentry event" do
          allow(Sentry).to receive(:capture_message)
          perform_enqueued_jobs
          expect(Sentry).not_to have_received(:capture_message).with(
            anything,
            extra: hash_including(
              ses_bounce: hash_including(
                :bounced_recipients,
              ),
            ),
          )
        end
      end

      context "when it is for a preview submission" do
        let(:mode) { "preview-live" }

        it "does not set failed_at on the delivery" do
          perform_enqueued_jobs
          expect(delivery.reload.failed_at).to be_nil
        end

        it "logs form event with preview flag" do
          perform_enqueued_jobs

          expect(log_lines).to include(hash_including(
                                         "level" => "INFO",
                                         "message" => "Form event",
                                         "event" => "form_submission_bounced",
                                         "preview" => "true",
                                       ))
        end

        it "does not alert to Sentry" do
          allow(Sentry).to receive(:capture_message)
          perform_enqueued_jobs
          expect(Sentry).not_to have_received(:capture_message)
        end
      end
    end

    describe "processing complaint notifications" do
      let(:event_type) { "Complaint" }
      let(:messages) { [sqs_message] }

      before do
        job = described_class.perform_later
        @job_id = job.job_id
      end

      it "logs complaint event with correct details" do
        perform_enqueued_jobs

        expect(log_lines).to include(hash_including(
                                       "level" => "INFO",
                                       "form_id" => submission.form_id,
                                       "submission_reference" => reference,
                                       "preview" => "false",
                                       "message" => "Form event",
                                       "event" => "form_submission_complaint",
                                       "job_id" => @job_id,
                                       "job_class" => "ReceiveSubmissionBouncesAndComplaintsJob",
                                     ))
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
  end

  context "when handling submission batch delivery bounces", :capture_logging do
    context "when the bounce is for a daily batch delivery" do
      let!(:delivery) { create :delivery, :daily_scheduled_delivery, delivery_reference:, submissions: [submission] }

      describe "processing bounce notifications" do
        let(:messages) { [sqs_message] }

        before do
          job = described_class.perform_later
          @job_id = job.job_id
        end

        context "when it is for a live submission" do
          let(:bounce_timestamp) { "2023-01-01T12:00:00Z" }
          let(:ses_message_body) do
            {
              "mail" => { "messageId" => delivery_reference },
              "eventType" => event_type,
              "bounce" => bounce,
            }
          end
          let(:bounce) do
            {
              "bounceType" => "Permanent",
              "bounceSubType" => "General",
              "bouncedRecipients" => bounced_recipients,
              "timestamp" => bounce_timestamp,
            }
          end
          let(:bounced_recipients) { [{ "emailAddress" => "bounce@example.com" }] }

          it "updates the delivery record with bounce details" do
            perform_enqueued_jobs

            expect(delivery.reload.failed_at).to eq(Time.zone.parse(bounce_timestamp))
            expect(delivery.reload.failure_reason).to eq("bounced")
            expect(delivery.reload.failure_details).to eq(bounce)
          end

          it "logs form event with correct details" do
            perform_enqueued_jobs

            expect(log_lines).to include(hash_including(
                                           "level" => "INFO",
                                           "message" => "Form event",
                                           "event" => "form_daily_batch_email_bounced",
                                           "form_id" => submission.form_id,
                                           "preview" => "false",
                                           "delivery_reference" => delivery_reference,
                                           "delivery_id" => delivery.id,
                                           "delivery_schedule" => "daily",
                                           "batch_begin_at" => delivery.batch_begin_at,
                                           "sqs_message_id" => sqs_message_id,
                                           "sns_message_timestamp" => sns_message_timestamp,
                                           "job_id" => @job_id,
                                           "job_class" => "ReceiveSubmissionBouncesAndComplaintsJob",
                                           "ses_bounce" => hash_including(
                                             "bounce_type" => "Permanent",
                                             "bounce_sub_type" => "General",
                                             "bounced_recipients" => [
                                               hash_including(
                                                 "email_address" => "bounce@example.com",
                                               ),
                                             ],
                                           ),
                                         ))
          end

          it "alerts to Sentry that there was a bounced delivery" do
            allow(Sentry).to receive(:capture_message)
            perform_enqueued_jobs
            expect(Sentry).to have_received(:capture_message).with(
              a_string_including("Daily submission batch email bounced for form #{submission.form_id} - ReceiveSubmissionBouncesAndComplaintsJob"),
              fingerprint: ["{{ default }}", submission.form_id],
              extra: hash_including(
                ses_bounce: hash_including(
                  bounce_type: "Permanent",
                  bounce_sub_type: "General",
                ),
              ),
            )
          end

          it "does not include bounced recipients in the Sentry event" do
            allow(Sentry).to receive(:capture_message)
            perform_enqueued_jobs
            expect(Sentry).not_to have_received(:capture_message).with(
              anything,
              extra: hash_including(
                ses_bounce: hash_including(
                  :bounced_recipients,
                ),
              ),
            )
          end
        end

        context "when it is for a preview submission" do
          let(:mode) { "preview-live" }

          it "does not set failed_at on the delivery" do
            perform_enqueued_jobs
            expect(delivery.reload.failed_at).to be_nil
          end

          it "logs form event with preview flag" do
            perform_enqueued_jobs

            expect(log_lines).to include(hash_including(
                                           "level" => "INFO",
                                           "message" => "Form event",
                                           "event" => "form_daily_batch_email_bounced",
                                           "preview" => "true",
                                         ))
          end

          it "does not alert to Sentry" do
            allow(Sentry).to receive(:capture_message)
            perform_enqueued_jobs
            expect(Sentry).not_to have_received(:capture_message)
          end
        end
      end

      describe "processing complaint notifications" do
        let(:event_type) { "Complaint" }
        let(:messages) { [sqs_message] }

        before do
          job = described_class.perform_later
          @job_id = job.job_id
        end

        it "logs complaint event with correct details" do
          perform_enqueued_jobs

          expect(log_lines).to include(hash_including(
                                         "level" => "INFO",
                                         "form_id" => submission.form_id,
                                         "preview" => "false",
                                         "message" => "Form event",
                                         "event" => "form_daily_batch_email_complaint",
                                         "job_id" => @job_id,
                                         "job_class" => "ReceiveSubmissionBouncesAndComplaintsJob",
                                       ))
        end
      end
    end

    context "when the bounce is for a weekly batch delivery" do
      let!(:delivery) { create :delivery, :weekly_scheduled_delivery, delivery_reference:, submissions: [submission] }

      describe "processing bounce notifications" do
        let(:messages) { [sqs_message] }

        before do
          job = described_class.perform_later
          @job_id = job.job_id
        end

        context "when it is for a live submission" do
          let(:bounce_timestamp) { "2023-01-01T12:00:00Z" }
          let(:ses_message_body) do
            {
              "mail" => { "messageId" => delivery_reference },
              "eventType" => event_type,
              "bounce" => bounce,
            }
          end
          let(:bounce) do
            {
              "bounceType" => "Permanent",
              "bounceSubType" => "General",
              "bouncedRecipients" => bounced_recipients,
              "timestamp" => bounce_timestamp,
            }
          end
          let(:bounced_recipients) { [{ "emailAddress" => "bounce@example.com" }] }

          it "updates the delivery record with bounce details" do
            perform_enqueued_jobs

            expect(delivery.reload.failed_at).to eq(Time.zone.parse(bounce_timestamp))
            expect(delivery.reload.failure_reason).to eq("bounced")
            expect(delivery.reload.failure_details).to eq(bounce)
          end

          it "logs form event with correct details" do
            perform_enqueued_jobs

            expect(log_lines).to include(hash_including(
                                           "level" => "INFO",
                                           "message" => "Form event",
                                           "event" => "form_weekly_batch_email_bounced",
                                           "form_id" => submission.form_id,
                                           "preview" => "false",
                                           "delivery_reference" => delivery_reference,
                                           "delivery_id" => delivery.id,
                                           "delivery_schedule" => "weekly",
                                           "batch_begin_at" => delivery.batch_begin_at,
                                           "sqs_message_id" => sqs_message_id,
                                           "sns_message_timestamp" => sns_message_timestamp,
                                           "job_id" => @job_id,
                                           "job_class" => "ReceiveSubmissionBouncesAndComplaintsJob",
                                           "ses_bounce" => hash_including(
                                             "bounce_type" => "Permanent",
                                             "bounce_sub_type" => "General",
                                             "bounced_recipients" => [
                                               hash_including(
                                                 "email_address" => "bounce@example.com",
                                               ),
                                             ],
                                           ),
                                         ))
          end

          it "alerts to Sentry that there was a bounced delivery" do
            allow(Sentry).to receive(:capture_message)
            perform_enqueued_jobs
            expect(Sentry).to have_received(:capture_message).with(
              a_string_including("Weekly submission batch email bounced for form #{submission.form_id} - ReceiveSubmissionBouncesAndComplaintsJob"),
              fingerprint: ["{{ default }}", submission.form_id],
              extra: hash_including(
                ses_bounce: hash_including(
                  bounce_type: "Permanent",
                  bounce_sub_type: "General",
                ),
              ),
            )
          end

          it "does not include bounced recipients in the Sentry event" do
            allow(Sentry).to receive(:capture_message)
            perform_enqueued_jobs
            expect(Sentry).not_to have_received(:capture_message).with(
              anything,
              extra: hash_including(
                ses_bounce: hash_including(
                  :bounced_recipients,
                ),
              ),
            )
          end
        end

        context "when it is for a preview submission" do
          let(:mode) { "preview-live" }

          it "does not set failed_at on the delivery" do
            perform_enqueued_jobs
            expect(delivery.reload.failed_at).to be_nil
          end

          it "logs form event with preview flag" do
            perform_enqueued_jobs

            expect(log_lines).to include(hash_including(
                                           "level" => "INFO",
                                           "message" => "Form event",
                                           "event" => "form_weekly_batch_email_bounced",
                                           "preview" => "true",
                                         ))
          end

          it "does not alert to Sentry" do
            allow(Sentry).to receive(:capture_message)
            perform_enqueued_jobs
            expect(Sentry).not_to have_received(:capture_message)
          end
        end
      end

      describe "processing complaint notifications" do
        let(:event_type) { "Complaint" }
        let(:messages) { [sqs_message] }

        before do
          job = described_class.perform_later
          @job_id = job.job_id
        end

        it "logs complaint event with correct details" do
          perform_enqueued_jobs

          expect(log_lines).to include(hash_including(
                                         "level" => "INFO",
                                         "form_id" => submission.form_id,
                                         "preview" => "false",
                                         "message" => "Form event",
                                         "event" => "form_weekly_batch_email_complaint",
                                         "job_id" => @job_id,
                                         "job_class" => "ReceiveSubmissionBouncesAndComplaintsJob",
                                       ))
        end
      end
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
