require "rails_helper"

RSpec.describe SendProgressSavedEmailJob, type: :job do
  let(:email_address) { "testing@example.gov.uk" }
  let(:form_document) { build(:form_document, name: "My form") }
  let(:incomplete_submission) do
    IncompleteSubmission.new(
      user_id: "user-1",
      form_id: form_document.form_id,
      form_version: 3,
      locale: "en",
      submission_reference: "ABC12345",
      mode: "form",
      updated_at: Time.zone.local(2026, 10, 12, 12, 0, 0),
    )
  end

  before do
    allow(Api::V3::FormDocumentRepository).to receive(:find_by_version)
      .with(form_id: incomplete_submission.form_id, version: 3, language: :en)
      .and_return(form_document)
  end

  it "sends the progress saved email" do
    expect {
      described_class.perform_now(incomplete_submission:, email_address:)
    }.to change(ActionMailer::Base.deliveries, :count).by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([email_address])
    expect(mail.subject).to eq(I18n.t("mailer.progress_saved.subject", form_name: "My form"))
  end

  it "passes the incomplete submission and email address to the mailer" do
    allow(ProgressSavedMailer).to receive(:progress_saved_email).and_call_original

    described_class.perform_now(incomplete_submission:, email_address:)

    expect(ProgressSavedMailer).to have_received(:progress_saved_email).with(incomplete_submission:, email_address:)
  end

  it "sets the logging attributes" do
    described_class.perform_now(incomplete_submission:, email_address:)

    expect(CurrentJobLoggingAttributes.job_class).to eq("SendProgressSavedEmailJob")
    expect(CurrentJobLoggingAttributes.submission_reference).to eq("ABC12345")
    expect(CurrentJobLoggingAttributes.form_id).to eq(form_document.form_id)
    expect(CurrentJobLoggingAttributes.form_name).to eq("My form")
    expect(CurrentJobLoggingAttributes.preview).to be false
    expect(CurrentJobLoggingAttributes.email_id).to be_present
  end

  context "when the job was enqueued with Welsh locale" do
    it "uses English as the default locale for the email" do
      I18n.with_locale(:cy) do
        described_class.perform_now(incomplete_submission:, email_address:)
      end

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq(I18n.t("mailer.progress_saved.subject", form_name: "My form", locale: :en))
    end
  end

  context "when there is an error during processing" do
    before do
      allow(ProgressSavedMailer).to receive(:progress_saved_email).and_raise(StandardError, "Test error")
      allow(CloudWatchService).to receive(:record_job_failure_metric)
    end

    it "raises the error" do
      expect {
        described_class.perform_now(incomplete_submission:, email_address:)
      }.to raise_error(StandardError, "Test error")
    end

    it "records a failure metric" do
      expect {
        described_class.perform_now(incomplete_submission:, email_address:)
      }.to raise_error(StandardError)

      expect(CloudWatchService).to have_received(:record_job_failure_metric).with("SendProgressSavedEmailJob")
    end
  end
end
