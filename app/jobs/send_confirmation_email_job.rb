class SendConfirmationEmailJob < ApplicationJob
  queue_as :confirmation_emails

  def perform(submission:, notify_response_id:, confirmation_email_address:, include_copy_of_answers: false)
    set_submission_logging_attributes(submission:)

    mail = if include_copy_of_answers
             AwsSesSubmissionConfirmationMailer.submission_confirmation_email(
               submission:, confirmation_email_address:, include_copy_of_answers:,
             )
           else
             FormSubmissionConfirmationMailer.send_confirmation_email(
               submission:, notify_response_id:, confirmation_email_address:,
             )
           end

    mail.deliver_now
    CurrentJobLoggingAttributes.confirmation_email_id = mail.govuk_notify_response&.id.presence || mail.message_id
  rescue StandardError
    CloudWatchService.record_job_failure_metric(self.class.name)
    raise
  end
end
