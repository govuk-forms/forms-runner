require "rails_helper"

RSpec.describe SendConfirmationEmailJob, type: :job do
  let(:submission_created_at) { Time.utc(2022, 12, 14, 13, 0o0, 0o0) }
  let(:form_document) do
    build(
      :v2_form_document,
      name: "Form 1",
      what_happens_next_markdown: "Please wait for a response",
      support_phone: "0203 222 2222",
      support_email: "help@example.gov.uk",
      support_url: "https://example.gov.uk/help",
      support_url_text: "Get help",
      payment_url: "https://www.gov.uk/payments/test-service/pay-for-licence",
    )
  end
  let(:submission) do
    create(
      :submission,
      form_document:,
      created_at: submission_created_at,
      reference: "ABC12345",
      submission_locale: "en",
    )
  end
  let(:notify_response_id) { "confirmation-ref" }
  let(:confirmation_email_address) { "testing@gov.uk" }

  before do
    Settings.govuk_notify.form_filler_confirmation_email_template_id = "123456"
    Settings.govuk_notify.form_filler_confirmation_email_welsh_template_id = "7891011"
  end

  it "sends the confirmation email" do
    expect {
      described_class.perform_now(
        submission:,
        notify_response_id:,
        confirmation_email_address:,
      )
    }.to change(ActionMailer::Base.deliveries, :count).by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["testing@gov.uk"])
  end

  it "builds mailer arguments from the submission" do
    allow(FormSubmissionConfirmationMailer).to receive(:send_confirmation_email).and_call_original

    described_class.perform_now(
      submission:,
      notify_response_id:,
      confirmation_email_address:,
    )

    expect(FormSubmissionConfirmationMailer).to have_received(:send_confirmation_email).with(
      what_happens_next_markdown: "Please wait for a response",
      what_happens_next_markdown_cy: nil,
      support_contact_details: have_attributes(
        phone: "0203 222 2222",
        call_charges_url: "https://www.gov.uk/call-charges",
        email: "help@example.gov.uk",
        url: "https://example.gov.uk/help",
        url_text: "Get help",
      ),
      support_contact_details_cy: nil,
      notify_response_id: "confirmation-ref",
      confirmation_email_address: "testing@gov.uk",
      mailer_options: an_instance_of(SendConfirmationEmailJob::MailerOptions),
      submission_locale: "en",
    )
  end

  context "when submission locale is Welsh" do
    let(:welsh_form_document) do
      build(:v2_form_document,
            what_happens_next_markdown: "Arhoswch am ymateb",
            support_phone: "0291 111 1111",
            support_email: "cymraeg@example.gov.uk")
    end

    before do
      submission.update!(submission_locale: "cy")
      allow(Api::V2::FormDocumentRepository).to receive(:find_with_mode).and_call_original
      allow(Api::V2::FormDocumentRepository).to receive(:find_with_mode).with(
        form_id: anything,
        mode: anything,
        language: :cy,
      ).and_return(welsh_form_document)
    end

    it "uses the bilingual template" do
      described_class.perform_now(
        submission:,
        notify_response_id:,
        confirmation_email_address:,
      )

      mail = ActionMailer::Base.deliveries.last
      expect(mail.govuk_notify_template).to eq("7891011")
    end

    it "passes the Welsh what happens next to the mailer" do
      allow(FormSubmissionConfirmationMailer).to receive(:send_confirmation_email).and_call_original

      described_class.perform_now(
        submission:,
        notify_response_id:,
        confirmation_email_address:,
      )

      expect(FormSubmissionConfirmationMailer).to have_received(:send_confirmation_email).with(
        hash_including(what_happens_next_markdown_cy: "Arhoswch am ymateb"),
      )
    end

    it "passes the Welsh support details" do
      allow(FormSubmissionConfirmationMailer).to receive(:send_confirmation_email).and_call_original

      described_class.perform_now(
        submission:,
        notify_response_id:,
        confirmation_email_address:,
      )

      expect(FormSubmissionConfirmationMailer).to have_received(:send_confirmation_email).with(
        hash_including(support_contact_details_cy: have_attributes(
          phone: "0291 111 1111",
          email: "cymraeg@example.gov.uk",
        )),
      )
    end
  end

  context "when there is an error during processing" do
    before do
      allow(FormSubmissionConfirmationMailer).to receive(:send_confirmation_email).and_raise(StandardError, "Test error")
      allow(CloudWatchService).to receive(:record_job_failure_metric)
    end

    it "raises an error" do
      expect {
        described_class.perform_now(
          submission:,
          notify_response_id:,
          confirmation_email_address:,
        )
      }.to raise_error(StandardError, "Test error")
    end

    it "sends cloudwatch metric for failure" do
      described_class.perform_now(
        submission:,
        notify_response_id:,
        confirmation_email_address:,
      )
      expect(CloudWatchService).to have_received(:record_job_failure_metric).with("SendConfirmationEmailJob")
    rescue StandardError
      nil
    end
  end
end
