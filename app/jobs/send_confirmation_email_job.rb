class SendConfirmationEmailJob < ApplicationJob
  queue_as :confirmation_emails

  # TODO: remove notify_response_id once deployed.
  # we are passing this is so as not to break any job already serialised in solid_queue at deploy time.
  # rubocop:disable Lint/UnusedMethodArgument
  def perform(submission:, confirmation_email_address:, notify_response_id: nil, include_copy_of_answers: false)
    set_submission_logging_attributes(submission:)
    # rubocop:enable Lint/UnusedMethodArgument
    # The job will use the locale at the time it was created. Force it to be "en" as we send multilingual emails for
    # forms submitted in Welsh.
    I18n.with_locale("en") do
      mail = SubmissionConfirmationMailer.submission_confirmation_email(
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
