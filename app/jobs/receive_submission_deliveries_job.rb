class ReceiveSubmissionDeliveriesJob < ApplicationJob
  queue_as :background

  def perform
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    poller = AwsSesMessagePoller.new(
      queue_name: Settings.aws.submission_email_deliveries_sqs_queue_name,
      job_class_name: self.class.name,
      job_id: job_id,
    )

    poller.poll do |ses_message_id, ses_message|
      CurrentJobLoggingAttributes.delivery_reference = ses_message_id
      delivery = Delivery.find_by!(delivery_reference: ses_message_id)
      submission = delivery.submissions.first
      ses_event_type = ses_message["eventType"]

      raise "Unexpected event type:#{ses_event_type}" unless ses_event_type == "Delivery"

      delivered_at = Time.zone.parse(ses_message["delivery"]["timestamp"])
      process_delivery(delivery, submission, delivered_at:)
    end
  end

private

  def process_delivery(delivery, submission, delivered_at:)
    delivery.update!(delivered_at:)

    if delivery.immediate?
      delivery_latency = ((delivery.delivered_at - submission.created_at) * 1000).round
      set_submission_logging_attributes(submission:, delivery:)
      CloudWatchService.record_submission_delivery_latency_metric(delivery_latency, "Email")
      EventLogger.log_form_event(
        "submission_delivered",
        { delivered_at: delivery.delivered_at, delivery_latency: },
      )
    elsif delivery.daily? || delivery.weekly?
      set_submission_batch_logging_attributes(form: submission.form, mode: submission.mode_object, delivery:)
      EventLogger.log_form_event("submission_batch_delivered")
    end
  end
end
