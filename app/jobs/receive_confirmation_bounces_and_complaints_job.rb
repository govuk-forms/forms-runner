class ReceiveConfirmationBouncesAndComplaintsJob < ApplicationJob
  def perform(*)
    CloudWatchService.record_job_started_metric(self.class.name)
    CurrentJobLoggingAttributes.job_class = self.class.name
    CurrentJobLoggingAttributes.job_id = job_id

    poller = AwsSesMessagePoller.new(
      queue_name: Settings.aws.confirmation_email_bounces_and_complaints_sqs_queue_name,
      job_class_name: self.class.name,
      job_id: job_id,
    )

    poller.poll do |ses_message_id, ses_message|
      CurrentJobLoggingAttributes.confirmation_email_id = ses_message_id
      ses_event_type = ses_message["eventType"]

      if ses_event_type == "Bounce"
        bounce_object = ses_message["bounce"] || {}
        ses_bounce = {
          bounce_type: bounce_object["bounceType"],
          bounce_sub_type: bounce_object["bounceSubType"],
          reporting_mta: bounce_object["reportingMTA"],
          timestamp: bounce_object["timestamp"],
          feedback_id: bounce_object["feedbackId"],
        }
        Rails.logger.info "Bounce notification received for confirmation email", { ses_bounce: }
      elsif ses_event_type == "Complaint"
        Rails.logger.info "Complaint notification received for confirmation email"
      else
        raise "Unexpected event type:#{ses_event_type}"
      end
    end
  end
end
