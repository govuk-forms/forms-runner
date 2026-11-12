require "rails_helper"

RSpec.describe DeleteIncompleteSubmissionsJob, type: :job do
  let!(:updated_31_days_ago) { create :incomplete_submission, updated_at: 31.days.ago }
  let!(:updated_29_days_ago) { create :incomplete_submission, updated_at: 29.days.ago }

  let(:form_document) { build(:form_document, name: "My form") }
  before do
    allow(CloudWatchService).to receive(:record_job_started_metric)
    allow(Api::V3::FormDocumentRepository).to receive(:find_by_version).and_return(form_document)
    allow(EventLogger).to receive(:log_form_event)
  end

  it "records the job started metric" do
    described_class.perform_now

    expect(CloudWatchService).to have_received(:record_job_started_metric).with("DeleteIncompleteSubmissionsJob")
  end

  it "deletes incomplete submissions last updated more than 30 days ago" do
    described_class.perform_now

    expect(IncompleteSubmission.exists?(updated_31_days_ago.id)).to be false
  end

  it "logs an event only for deleted incomplete submissions" do
    described_class.perform_now

    expect(EventLogger).to have_received(:log_form_event).with("incomplete_submission_deleted").once
  end

  it "sets the logging attributes for the deleted incomplete submission when logging the event" do
    attributes = nil
    allow(EventLogger).to receive(:log_form_event) do
      attributes = {
        submission_uuid: CurrentJobLoggingAttributes.submission_uuid,
        form_id: CurrentJobLoggingAttributes.form_id,
        form_name: CurrentJobLoggingAttributes.form_name,
      }
    end

    described_class.perform_now

    expect(attributes).to eq(submission_uuid: updated_31_days_ago.submission_uuid, form_id: updated_31_days_ago.form_id, form_name: "My form")
  end

  context "when the incomplete submission changes after it has been queried" do
    def after_querying_incomplete_submission(&block)
      allow(CurrentJobLoggingAttributes).to receive(:submission_uuid=).and_wrap_original do |original, submission_uuid|
        block.call(IncompleteSubmission.find_by(submission_uuid:))
        original.call(submission_uuid)
      end
    end

    context "when it has been updated" do
      before do
        after_querying_incomplete_submission(&:touch)
      end

      it "does not delete the incomplete submission" do
        described_class.perform_now

        expect(IncompleteSubmission.exists?(updated_31_days_ago.id)).to be true
      end
    end

    context "when it has already been deleted" do
      before do
        allow(Sentry).to receive(:capture_exception)
        after_querying_incomplete_submission { |incomplete_submission| incomplete_submission&.destroy! }
      end

      it "does not report an error" do
        described_class.perform_now

        expect(Sentry).not_to have_received(:capture_exception)
      end

      it "does not log an event" do
        described_class.perform_now

        expect(EventLogger).not_to have_received(:log_form_event)
      end
    end
  end

  it "keeps incomplete submissions updated within the last 30 days" do
    described_class.perform_now

    expect(IncompleteSubmission.exists?(updated_29_days_ago.id)).to be true
  end
end
