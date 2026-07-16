class SendS3SubmissionJob < SubmissionDeliveryJob
  def perform(delivery_or_submission)
    delivery, submission = resolve_delivery_and_submission(delivery_or_submission)
    set_submission_logging_attributes(submission:, delivery:)

    delivery.new_attempt!

    key = S3SubmissionService.new(submission:).submit

    delivery.update!(delivery_reference: key)
    record_submission_sent!
  rescue StandardError
    CloudWatchService.record_job_failure_metric(self.class.name)
    raise
  end
end
