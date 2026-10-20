class ApplicationJob < ActiveJob::Base
  def set_submission_logging_attributes(submission:, delivery: nil)
    set_job_logging_attributes
    CurrentJobLoggingAttributes.form_id = submission.form.id
    CurrentJobLoggingAttributes.form_name = submission.form.name
    CurrentJobLoggingAttributes.form_version = submission.form.version
    CurrentJobLoggingAttributes.submission_reference = submission.reference
    CurrentJobLoggingAttributes.preview = submission.preview?
    CurrentJobLoggingAttributes.delivery_id = delivery&.id
    CurrentJobLoggingAttributes.delivery_reference = delivery&.delivery_reference
    CurrentJobLoggingAttributes.delivery_method = delivery&.delivery_method
    CurrentJobLoggingAttributes.delivery_formats = delivery&.formats
  end

  def set_submission_batch_logging_attributes(form:, mode:, delivery:)
    set_job_logging_attributes
    CurrentJobLoggingAttributes.form_id = form.id
    CurrentJobLoggingAttributes.form_name = form.name
    CurrentJobLoggingAttributes.form_version = form.version
    CurrentJobLoggingAttributes.preview = mode.preview?
    CurrentJobLoggingAttributes.delivery_id = delivery.id
    CurrentJobLoggingAttributes.delivery_reference = delivery.delivery_reference
    CurrentJobLoggingAttributes.delivery_schedule = delivery.delivery_schedule
    CurrentJobLoggingAttributes.batch_begin_at = delivery.batch_begin_at
  end

  def set_incomplete_submission_logging_attributes(incomplete_submission:)
    set_job_logging_attributes
    CurrentJobLoggingAttributes.submission_reference = incomplete_submission.submission_reference
    CurrentJobLoggingAttributes.form_id = incomplete_submission.form.id
    CurrentJobLoggingAttributes.form_name = incomplete_submission.form.name
    CurrentJobLoggingAttributes.form_version = incomplete_submission.form.version
    CurrentJobLoggingAttributes.preview = incomplete_submission.mode_object.preview?
  end

private

  def set_job_logging_attributes
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id
  end
end
