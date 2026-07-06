require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe SendSubmissionBatchJob, type: :job do
  include ActiveJob::TestHelper

  let(:mode_string) { "form" }
  let(:date) { Date.new(2025, 4, 10) }
  let(:batch_begin_at) { Time.utc(2025, 4, 9, 23, 0, 0) }
  let(:delivery) { create(:delivery, delivery_schedule: "daily", submissions:, batch_begin_at:) }

  let(:form_document) { build(:v2_form_document, :with_steps, name: "My Form", submission_email:) }
  let(:submission_email) { "to@example.com" }
  let(:form_id) { form_document.form_id }
  let(:submissions) { [] }

  before do
    submissions
    ActionMailer::Base.deliveries.clear
    job = described_class.perform_later(delivery:)
    @job_id = job.job_id
  end

  context "when there are no submissions" do
    it "raises an error and does not send an email" do
      expect {
        perform_enqueued_jobs
      }.to raise_error(StandardError, "No submissions found for delivery id: #{delivery.id} when running job: #{@job_id}")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when there are submissions" do
    let(:submissions) do
      create_list(
        :submission,
        3,
        form_document:,
        form_id:,
        mode: mode_string,
        created_at: date.beginning_of_day + 1.hour,
      )
    end

    context "when the form does not have a submission email address" do
      let(:submission_email) { nil }

      it "raises an error" do
        expect {
          perform_enqueued_jobs
        }.to raise_error(StandardError, "Form id: #{form_id} is missing a submission email address")
      end

      context "when the mode is preview" do
        let(:mode_string) { "preview-live" }

        it "does not call the submission batch service" do
          perform_enqueued_jobs
          expect(AwsSesSubmissionBatchService).not_to receive(:new)
        end
      end
    end

    context "when the form has a submission email address", :capture_logging do
      let(:mail) { ActionMailer::Base.deliveries.last }

      before do
        @job_ran_at = Time.zone.now
        perform_enqueued_jobs
      end

      it "updates the delivery" do
        expect(delivery.reload.delivery_reference).to eq(mail.message_id)
        expect(delivery.reload.last_attempt_at).to be_within(1.second).of(@job_ran_at)
      end

      context "when the delivery has already been attempted" do
        let(:delivery) do
          create(:delivery,
                 delivery_schedule: "daily",
                 submissions:,
                 batch_begin_at:,
                 delivered_at: Time.zone.now - 2.hours,
                 failed_at: Time.zone.now - 1.hour,
                 failure_reason: "bounced")
        end

        it "resets the delivery details" do
          expect(delivery.reload.delivered_at).to be_nil
          expect(delivery.reload.failed_at).to be_nil
          expect(delivery.reload.failure_reason).to be_nil
        end
      end

      context "when the delivery is for a daily batch" do
        it "sends an email" do
          expect(ActionMailer::Base.deliveries.count).to eq(1)
          expect(mail.to).to include(form_document.submission_email)
        end

        it "includes the date in London time in the subject" do
          expect(mail.subject).to include("10 April 2025")
        end

        it "attaches a csv with the expected filename" do
          expect(mail.attachments).not_to be_empty

          filenames = mail.attachments.map(&:filename)
          expect(filenames).to contain_exactly("govuk_forms_my_form_2025-04-10.csv")
        end

        it "attaches a csv containing header plus one line per submission" do
          csv_content = mail.attachments.first.decoded
          expect(csv_content.lines.count).to eq(submissions.count + 1)
        end

        it "logs that the email was sent" do
          expect(log_lines).to include(
            hash_including(
              "event" => "form_daily_batch_email_sent",
              "form_id" => form_id,
              "mode" => mode_string,
              "preview" => "false",
              "batch_begin_date" => date.to_s,
              "number_of_submissions" => submissions.count,
              "delivery_reference" => mail.message_id,
              "delivery_id" => delivery.id,
              "job_id" => @job_id,
            ),
          )
        end

        it "logs each submission included in the batch" do
          expect(log_lines).to include(
            hash_including(
              "event" => "form_included_in_daily_batch_email",
              "batch_begin_date" => date.to_s,
              "submission_reference" => submissions.first.reference,
              "delivery_reference" => mail.message_id,
            ),
            hash_including(
              "event" => "form_included_in_daily_batch_email",
              "batch_begin_date" => date.to_s,
              "submission_reference" => submissions.second.reference,
              "delivery_reference" => mail.message_id,
            ),
          )
        end
      end

      context "when the delivery is for a weekly batch" do
        let(:delivery) { create(:delivery, delivery_schedule: "weekly", submissions:, batch_begin_at:) }

        it "sends an email" do
          expect(ActionMailer::Base.deliveries.count).to eq(1)
          expect(mail.to).to include(form_document.submission_email)
        end

        it "includes the date range in London time in the subject" do
          expect(mail.subject).to include("10 April 2025 to 16 April 2025")
        end

        it "attaches a csv containing header plus one line per submission" do
          csv_content = mail.attachments.first.decoded
          expect(csv_content.lines.count).to eq(submissions.count + 1)
        end

        it "logs that the email was sent" do
          expect(log_lines).to include(
            hash_including(
              "event" => "form_weekly_batch_email_sent",
              "form_id" => form_id,
              "mode" => mode_string,
              "preview" => "false",
              "batch_begin_date" => date.to_s,
              "number_of_submissions" => submissions.count,
              "delivery_reference" => mail.message_id,
              "delivery_id" => delivery.id,
              "job_id" => @job_id,
            ),
          )
        end

        it "logs each submission included in the batch" do
          expect(log_lines).to include(
            hash_including(
              "event" => "form_included_in_weekly_batch_email",
              "batch_begin_date" => date.to_s,
              "submission_reference" => submissions.first.reference,
              "delivery_reference" => mail.message_id,
            ),
            hash_including(
              "event" => "form_included_in_weekly_batch_email",
              "batch_begin_date" => date.to_s,
              "submission_reference" => submissions.second.reference,
              "delivery_reference" => mail.message_id,
            ),
          )
        end
      end
    end

    context "when the form settings have changed between submissions" do
      let(:new_form_document) { build(:v2_form_document, :with_steps, name: "New form name", submission_email: "new-email@example.gov.uk") }
      let(:submissions) do
        [
          create(:submission, form_document: form_document, form_id:, mode: mode_string, created_at: date.end_of_day - 3.hours),
          # we should use the form details from this submission as it is the most recent
          create(:submission, form_document: new_form_document, form_id:, mode: mode_string, created_at: date.end_of_day - 1.hour),
          create(:submission, form_document: form_document, form_id:, mode: mode_string, created_at: date.end_of_day - 2.hours),
        ]
      end

      before do
        perform_enqueued_jobs
      end

      it "sends an email to the new submission email address" do
        expect(ActionMailer::Base.deliveries.count).to eq(1)

        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to include(new_form_document.submission_email)
      end

      it "uses the form name from the most recent submission" do
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to include(new_form_document.name)
      end
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
