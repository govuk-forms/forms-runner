class SendConfirmationEmailJob < ApplicationJob
  queue_as :confirmation_emails

  def perform(submission:, confirmation_email_address:, include_copy_of_answers: false)
    set_submission_logging_attributes(submission:)

    # The job will use the locale at the time it was created. Force it to be "en" as we send multilingual emails for
    # forms submitted in Welsh.
    I18n.with_locale("en") do
      mail = AwsSesSubmissionConfirmationMailer.submission_confirmation_email(
        submission:, confirmation_email_address:, include_copy_of_answers:,
      )

      mail.deliver_now
      CurrentJobLoggingAttributes.confirmation_email_id = mail.message_id
    end
  rescue StandardError
    CloudWatchService.record_job_failure_metric(self.class.name)
    raise
  end
end
