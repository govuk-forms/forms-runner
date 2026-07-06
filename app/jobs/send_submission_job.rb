class SendSubmissionJob < SubmissionDeliveryJob
  # this translates to approximately 4.5 hours of retrying in total
  TOTAL_ATTEMPTS = 10

  retry_on Aws::SESV2::Errors::ServiceError, wait: :polynomially_longer, attempts: TOTAL_ATTEMPTS

  def perform(submission)
    # The job will use the locale at the time it was created. Force it to be "en" as we always send submission emails in
    # English.
    I18n.with_locale("en") do
      delivery = submission.single_submission_delivery
      set_submission_logging_attributes(submission:, delivery:)

      delivery.new_attempt!

      message_id = AwsSesSubmissionService.new(submission:).submit

      delivery.update!(delivery_reference: message_id)
      record_submission_sent!
    end
  rescue StandardError
    CloudWatchService.record_job_failure_metric(self.class.name)
    raise
  end
end
