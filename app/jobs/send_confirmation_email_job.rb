class SendConfirmationEmailJob < ApplicationJob
  queue_as :confirmation_emails
  MailerOptions = Data.define(:title, :is_preview, :timestamp, :submission_reference, :payment_url)

  def perform(submission:, notify_response_id:, confirmation_email_address:)
    set_submission_logging_attributes(submission:)

    form = submission.form
    welsh_form = fetch_welsh_form(submission:, form:)
    mail = FormSubmissionConfirmationMailer.send_confirmation_email(
      what_happens_next_markdown: form.what_happens_next_markdown,
      what_happens_next_markdown_cy: welsh_form&.what_happens_next_markdown,
      support_contact_details: form.support_details,
      support_contact_details_cy: welsh_form&.support_details,
      notify_response_id:,
      confirmation_email_address:,
      mailer_options: mailer_options_for(submission:, form:),
      submission_locale: submission.submission_locale,
    )

    mail.deliver_now
    CurrentJobLoggingAttributes.confirmation_email_id = mail.govuk_notify_response.id
  rescue StandardError
    CloudWatchService.record_job_failure_metric(self.class.name)
    raise
  end

private

  def mailer_options_for(submission:, form:)
    MailerOptions.new(
      title: form.name,
      is_preview: submission.preview?,
      timestamp: submission.submission_time,
      submission_reference: submission.reference,
      payment_url: submission.payment_url,
    )
  end

  def fetch_welsh_form(submission:, form:)
    return nil unless submission.submission_locale.to_sym == :cy

    form_document = Api::V2::FormDocumentRepository.find_with_mode(
      form_id: form.id,
      mode: submission.mode_object,
      language: :cy,
    )
    Form.new(form_document) if form_document
  end
end
