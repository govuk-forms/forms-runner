class SubmissionDeliveryJob < ApplicationJob
  queue_as :submissions

private

  def resolve_delivery_and_submission(argument)
    case argument
    when Delivery
      [argument, argument.submissions.sole]
    when Submission
      [argument.single_submission_delivery, argument]
    else
      raise ArgumentError, "Expected a Delivery or Submission, got #{argument.class}"
    end
  end

  def record_submission_sent!
    milliseconds_since_scheduled = (Time.current - scheduled_at_or_enqueued_at).in_milliseconds.round
    EventLogger.log_form_event("submission_sent", { milliseconds_since_scheduled: })
    CloudWatchService.record_submission_sent_metric(milliseconds_since_scheduled)
  end

  def scheduled_at_or_enqueued_at
    scheduled_at || enqueued_at
  end
end
