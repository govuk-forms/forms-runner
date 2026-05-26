class SendConfirmationEmailJob < ApplicationJob
  queue_as :confirmation_emails

  def perform(submission:, notify_response_id:, confirmation_email_address:)
    set_submission_logging_attributes(submission:)

    mail = FormSubmissionConfirmationMailer.send_confirmation_email(
      submission:,
      notify_response_id:,
      confirmation_email_address:,
    )

    mail.deliver_now
    CurrentJobLoggingAttributes.confirmation_email_id = mail.govuk_notify_response.id
  rescue StandardError
    CloudWatchService.record_job_failure_metric(self.class.name)
    raise
  end
end
