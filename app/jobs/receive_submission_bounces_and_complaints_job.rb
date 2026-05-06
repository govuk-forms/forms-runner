class ReceiveSubmissionBouncesAndComplaintsJob < ApplicationJob
  queue_as :background

  SQS_QUEUE_NAME = "submission_email_ses_bounces_and_complaints_queue".freeze

  def perform
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    poller = AwsSesMessagePoller.new(
      queue_name: SQS_QUEUE_NAME,
      job_class_name: self.class.name,
      job_id: job_id,
    )

    poller.poll do |delivery, ses_message|
      submission = delivery.submissions.first
      ses_event_type = ses_message["eventType"]

      raise "Unexpected event type:#{ses_event_type}" unless %w[Bounce Complaint].include?(ses_event_type)

      set_logging_attributes(submission:, delivery:)

      process_bounce(delivery, submission, ses_message) if ses_event_type == "Bounce"
      process_complaint(delivery) if ses_event_type == "Complaint"
    end
  end

private

  def set_logging_attributes(submission:, delivery:)
    if delivery.immediate?
      set_submission_logging_attributes(submission:, delivery:)
    elsif delivery.daily? || delivery.weekly?
      set_submission_batch_logging_attributes(form: submission.form, mode: submission.mode_object, delivery:)
    end
  end

  def process_bounce(delivery, submission, ses_message)
    bounce_object = ses_message["bounce"] || {}

    unless submission.preview?
      bounced_timestamp = Time.zone.parse(bounce_object["timestamp"])

      delivery.update!(
        failed_at: bounced_timestamp,
        failure_reason: "bounced",
        failure_details: bounce_object,
      )
    end

    ses_bounce = {
      bounce_type: bounce_object["bounceType"],
      bounce_sub_type: bounce_object["bounceSubType"],
      reporting_mta: bounce_object["reportingMTA"],
      timestamp: bounce_object["timestamp"],
      feedback_id: bounce_object["feedbackId"],
    }

    bounced_recipients = bounce_object["bouncedRecipients"]&.map do |recipient|
      {
        email_address: recipient["emailAddress"],
        action: recipient["action"],
        status: recipient["status"],
        diagnostic_code: recipient["diagnosticCode"],
      }
    end

    case delivery.delivery_schedule
    when "immediate"
      process_immediate_delivery_bounce(delivery, submission, ses_bounce, bounced_recipients)
    when "daily"
      process_daily_delivery_bounce(delivery, submission, ses_bounce, bounced_recipients)
    when "weekly"
      process_weekly_delivery_bounce(delivery, submission, ses_bounce, bounced_recipients)
    end
  end

  def process_immediate_delivery_bounce(delivery, submission, ses_bounce, bounced_recipients)
    EventLogger.log_form_event("submission_bounced", ses_bounce: ses_bounce.merge(bounced_recipients:))

    unless submission.preview?
      Sentry.capture_message("Submission email bounced for form #{submission.form_id} - #{self.class.name}:",
                             fingerprint: ["{{ default }}", submission.form_id],
                             extra: {
                               form_id: submission.form_id,
                               submission_reference: submission.reference,
                               delivery_reference: delivery.delivery_reference,
                               delivery_id: delivery.id,
                               job_id:,
                               ses_bounce:,
                             })
    end
  end

  def process_daily_delivery_bounce(delivery, submission, ses_bounce, bounced_recipients)
    EventLogger.log_form_event("daily_batch_email_bounced", ses_bounce: ses_bounce.merge(bounced_recipients:))

    unless submission.preview?
      Sentry.capture_message("Daily submission batch email bounced for form #{submission.form_id} - #{self.class.name}:",
                             fingerprint: ["{{ default }}", submission.form_id],
                             extra: {
                               form_id: submission.form_id,
                               delivery_reference: delivery.delivery_reference,
                               delivery_id: delivery.id,
                               delivery_schedule: delivery.delivery_schedule,
                               batch_begin_at: delivery.batch_begin_at,
                               job_id:,
                               ses_bounce:,
                             })
    end
  end

  def process_weekly_delivery_bounce(delivery, submission, ses_bounce, bounced_recipients)
    EventLogger.log_form_event("weekly_batch_email_bounced", ses_bounce: ses_bounce.merge(bounced_recipients:))

    unless submission.preview?
      Sentry.capture_message("Weekly submission batch email bounced for form #{submission.form_id} - #{self.class.name}:",
                             fingerprint: ["{{ default }}", submission.form_id],
                             extra: {
                               form_id: submission.form_id,
                               delivery_reference: delivery.delivery_reference,
                               delivery_id: delivery.id,
                               delivery_schedule: delivery.delivery_schedule,
                               batch_begin_at: delivery.batch_begin_at,
                               job_id:,
                               ses_bounce:,
                             })
    end
  end

  def process_complaint(delivery)
    if delivery.immediate?
      EventLogger.log_form_event("submission_complaint")
    elsif delivery.daily?
      EventLogger.log_form_event("daily_batch_email_complaint")
    elsif delivery.weekly?
      EventLogger.log_form_event("weekly_batch_email_complaint")
    end
  end
end
