class DeleteIncompleteSubmissionsJob < ApplicationJob
  queue_as :background

  def perform(*_args)
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    updated_before = Settings.incomplete_submissions.maximum_retention_seconds.seconds.ago
    IncompleteSubmission.where(updated_at: ..updated_before)
                        .find_each { |incomplete_submission| delete_incomplete_submission(incomplete_submission, updated_before: updated_before) }
  end

private

  def delete_incomplete_submission(incomplete_submission, updated_before:)
    set_incomplete_submission_logging_attributes(incomplete_submission:)

    # Ensure the incomplete submission hasn't been updated since we queried, and lock it so it can't be updated before
    # it's deleted
    deleted = incomplete_submission.with_lock do
      next false if incomplete_submission.updated_at > updated_before

      incomplete_submission.destroy!
    end
    return unless deleted

    EventLogger.log_form_event("incomplete_submission_deleted")
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => e
    Rails.logger.warn("Error deleting incomplete submission - #{e.class.name}: #{e.message}")
    Sentry.capture_exception(e)
  ensure
    CurrentJobLoggingAttributes.reset
  end
end
