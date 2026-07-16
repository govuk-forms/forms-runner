require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe SendSubmissionJob, type: :job do
  include ActiveJob::TestHelper

  let(:submission_created_at) { Time.utc(2022, 12, 14, 13, 0o0, 0o0) }
  let(:submission) do
    create(:submission, :sent, form_document:, created_at: submission_created_at, answers:)
  end
  let(:delivery) { submission.deliveries.first }
  let(:form_document) do
    build(:v2_form_document,
          :ready_for_live,
          name: "Form 1",
          steps: [build(:v2_selection_question_step, is_optional: true, only_one_option: "true", id: "q1")],
          start_page: "q1")
  end
  let(:answers) { { "q1" => { selection: Question::Selection::NONE_OF_THE_ABOVE_VALUE } } }
  let(:aws_ses_submission_service_spy) { instance_double(AwsSesSubmissionService) }
  let(:delivery_reference) { "1234" }

  before do
    allow(CloudWatchService).to receive(:record_submission_sent_metric)
    allow(CloudWatchService).to receive(:record_job_failure_metric)
  end

  context "when the job is processed with a Delivery argument" do
    before do
      allow(AwsSesSubmissionService).to receive(:new).with(submission:).and_return(aws_ses_submission_service_spy)
      allow(aws_ses_submission_service_spy).to receive(:submit).and_return(delivery_reference)

      described_class.perform_later(delivery)
      travel 5.seconds do
        @job_ran_at = Time.zone.now
        perform_enqueued_jobs
      end
    end

    it "submits via AWS SES" do
      expect(aws_ses_submission_service_spy).to have_received(:submit)
    end

    it "sets the delivery reference on the existing delivery record" do
      expect(delivery.reload.delivery_reference).to eq(delivery_reference)
    end

    it "sets the last attempt time on the existing delivery record" do
      expect(delivery.reload.last_attempt_at).to be_within(1.second).of(@job_ran_at)
    end

    it "sends cloudwatch metric for the submission being sent" do
      expect(CloudWatchService).to have_received(:record_submission_sent_metric).with(
        satisfy { |value| value.is_a?(Integer) && value >= 0 },
      )
    end

    context "when the delivery is being retried" do
      let(:submission) do
        delivery = create(:delivery,
                          delivery_reference: "old-ref",
                          delivered_at: Time.zone.now,
                          failed_at: Time.zone.now,
                          failure_reason: "bounced")
        create(:submission, form_document:, deliveries: [delivery])
      end

      it "clears the delivery status fields" do
        updated_delivery = delivery.reload
        expect(updated_delivery.delivery_reference).to eq(delivery_reference)
        expect(updated_delivery.last_attempt_at).to be_within(1.second).of(@job_ran_at)
        expect(updated_delivery.delivered_at).to be_nil
        expect(updated_delivery.failed_at).to be_nil
        expect(updated_delivery.failure_reason).to be_nil
      end
    end
  end

  context "when there is an error during processing" do
    context "and the error is an Aws::SESV2::Errors::ServiceError" do
      before do
        allow(AwsSesSubmissionService).to receive(:new).with(submission:).and_return(aws_ses_submission_service_spy)
        allow(aws_ses_submission_service_spy).to receive(:submit).and_raise(Aws::SESV2::Errors::ServiceError.new(nil, "Test SES error", nil))
        allow(CloudWatchService).to receive(:record_job_failure_metric)
      end

      it "retries for the configured number of attempts" do
        assert_performed_jobs SendSubmissionJob::TOTAL_ATTEMPTS do
          described_class.perform_later(delivery)
        rescue Aws::SESV2::Errors::ServiceError # If we don't catch the error, the test aborts prematurely
          nil
        end
      end

      it "raises an error after all attempts fail" do
        expect { described_class.new.perform(delivery) }.to raise_error(Aws::SESV2::Errors::ServiceError)
      end

      it "sends cloudwatch metric for failure" do
        described_class.new.perform(delivery)
        expect(CloudWatchService).to have_received(:record_job_failure_metric).with("SendSubmissionJob")
      rescue Aws::SESV2::Errors::ServiceError # If we don't catch the error, the test aborts prematurely
        nil
      end
    end

    context "and the error is any other error" do
      before do
        allow(aws_ses_submission_service_spy).to receive(:submit).and_raise(StandardError, "Test error")
      end

      it "doesn't retry" do
        assert_performed_jobs 1 do
          described_class.perform_later(delivery)
        rescue StandardError # If we don't catch the error, the test aborts prematurely
          nil
        end
      end

      it "raises an error immediately" do
        expect { described_class.new.perform(delivery) }.to raise_error(StandardError)
      end

      it "sends cloudwatch metric for failure" do
        described_class.new.perform(delivery)
        expect(CloudWatchService).to have_received(:record_job_failure_metric).with("SendSubmissionJob")
      rescue StandardError # If we don't catch the error, the test aborts prematurely
        nil
      end
    end
  end

  context "when the job was enqueued with Welsh locale" do
    it "uses English I18n translations in the submission email" do
      I18n.with_locale(:cy) do
        described_class.perform_later(delivery)
        perform_enqueued_jobs
      end

      mail = ActionMailer::Base.deliveries.last
      # We don't have Welsh translations for most email content, but we do for the "None of the above" answer
      expect(mail.body.parts[0].decoded).to include(I18n.t("page.none_of_the_above", locale: :en))
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
