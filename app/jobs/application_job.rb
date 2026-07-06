class ApplicationJob < ActiveJob::Base
  def set_submission_logging_attributes(submission:, delivery: nil)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id
    CurrentJobLoggingAttributes.form_id = submission.form.id
    CurrentJobLoggingAttributes.form_name = submission.form.name
    CurrentJobLoggingAttributes.submission_reference = submission.reference
    CurrentJobLoggingAttributes.preview = submission.preview?
    CurrentJobLoggingAttributes.delivery_id = delivery&.id
    CurrentJobLoggingAttributes.delivery_reference = delivery&.delivery_reference
  end

  def set_submission_batch_logging_attributes(form:, mode:, delivery:)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id
    CurrentJobLoggingAttributes.form_id = form.id
    CurrentJobLoggingAttributes.form_name = form.name
    CurrentJobLoggingAttributes.preview = mode.preview?
    CurrentJobLoggingAttributes.delivery_id = delivery.id
    CurrentJobLoggingAttributes.delivery_reference = delivery.delivery_reference
    CurrentJobLoggingAttributes.delivery_schedule = delivery.delivery_schedule
    CurrentJobLoggingAttributes.batch_begin_at = delivery.batch_begin_at
  end
end
