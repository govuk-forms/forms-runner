class ApplicationJob < ActiveJob::Base
  def set_submission_logging_attributes(submission:, delivery: nil)
    set_job_logging_attributes
    CurrentJobLoggingAttributes.form_id = submission.form_id
    CurrentJobLoggingAttributes.form_name = submission.form_name
    CurrentJobLoggingAttributes.form_version = submission.form_version
    CurrentJobLoggingAttributes.submission_reference = submission.reference
    CurrentJobLoggingAttributes.submission_uuid = submission.submission_uuid
    CurrentJobLoggingAttributes.preview = submission.preview?
    CurrentJobLoggingAttributes.delivery_id = delivery&.id
    CurrentJobLoggingAttributes.delivery_reference = delivery&.delivery_reference
    CurrentJobLoggingAttributes.delivery_method = delivery&.delivery_method
    CurrentJobLoggingAttributes.delivery_formats = delivery&.formats
  end

  def set_submission_batch_logging_attributes(included_submission:, delivery:)
    set_job_logging_attributes
    CurrentJobLoggingAttributes.form_id = included_submission.form_id
    CurrentJobLoggingAttributes.form_name = included_submission.form_name
    CurrentJobLoggingAttributes.form_version = included_submission.form_version
    CurrentJobLoggingAttributes.preview = included_submission.preview?
    CurrentJobLoggingAttributes.delivery_id = delivery.id
    CurrentJobLoggingAttributes.delivery_reference = delivery.delivery_reference
    CurrentJobLoggingAttributes.delivery_schedule = delivery.delivery_schedule
    CurrentJobLoggingAttributes.batch_begin_at = delivery.batch_begin_at
  end

  def set_incomplete_submission_logging_attributes(incomplete_submission:)
    set_job_logging_attributes
    CurrentJobLoggingAttributes.submission_reference = incomplete_submission.submission_reference
    CurrentJobLoggingAttributes.submission_uuid = incomplete_submission.submission_uuid
    CurrentJobLoggingAttributes.form_id = incomplete_submission.form_id
    CurrentJobLoggingAttributes.form_name = incomplete_submission.form.name
    CurrentJobLoggingAttributes.form_version = incomplete_submission.form_version
    CurrentJobLoggingAttributes.preview = incomplete_submission.mode_object.preview?
  end

private

  def set_job_logging_attributes
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id
  end
end
