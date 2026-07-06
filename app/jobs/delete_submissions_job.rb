class DeleteSubmissionsJob < ApplicationJob
  queue_as :background

  def perform(*_args)
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    delete_all_submissions_created_before_time = Settings.submissions.maximum_retention_seconds.seconds.ago
    submissions_past_max_retention = Submission
      .where(created_at: ..delete_all_submissions_created_before_time)

    submissions_past_max_retention.find_each { |submission| delete_submission_data(submission) }
  end

  def delete_submission_data(submission)
    set_submission_logging_attributes(submission:)
    delivery_status = submission&.single_submission_delivery&.status

    files = submission.journey.completed_file_upload_questions
    files.each(&:delete_from_s3)
    submission.destroy!

    EventLogger.log_form_event("submission_deleted", { delivery_status: })
    CloudWatchService.record_submission_deleted_metric(delivery_status)
  rescue StandardError => e
    Rails.logger.warn("Error deleting submission - #{e.class.name}: #{e.message}")
    Sentry.capture_exception(e)
  ensure
    CurrentJobLoggingAttributes.reset
  end
end
