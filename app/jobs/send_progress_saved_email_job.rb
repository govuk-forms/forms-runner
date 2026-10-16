class SendProgressSavedEmailJob < ApplicationJob
  queue_as :confirmation_emails

  def perform(incomplete_submission:, email_address:)
    set_incomplete_submission_logging_attributes(incomplete_submission:)

    # The job will use the locale at the time it was created. Force it to be "en" as we send multilingual emails for
    # forms submitted in Welsh.
    I18n.with_locale("en") do
      mail = ProgressSavedMailer.progress_saved_email(incomplete_submission:, email_address:)

      mail.deliver_now
      CurrentJobLoggingAttributes.email_id = mail.message_id
    end
  rescue StandardError
    CloudWatchService.record_job_failure_metric(self.class.name)
    raise
  end
end
