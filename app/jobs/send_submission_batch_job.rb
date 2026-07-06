class SendSubmissionBatchJob < ApplicationJob
  queue_as :submissions

  # this translates to approximately 4.5 hours of retrying in total
  TOTAL_ATTEMPTS = 10

  retry_on Aws::SESV2::Errors::ServiceError, wait: :polynomially_longer, attempts: TOTAL_ATTEMPTS

  def perform(delivery:)
    submissions = delivery.submissions

    if submissions.empty?
      raise StandardError, "No submissions found for delivery id: #{delivery.id} when running job: #{job_id}"
    end

    # Get the form details from the latest submission to get the most recent submission email and form name.
    latest_submission = submissions.order(created_at: :desc).first
    form = latest_submission.form
    mode = latest_submission.mode_object

    batch_begin_date = delivery.batch_begin_at.in_time_zone(TimeZoneUtils.submission_time_zone).to_date

    set_submission_batch_logging_attributes(form:, mode:, delivery:)

    if form.submission_email.blank?
      if mode.preview?
        Rails.logger.info "Skipping sending batch for preview submissions, as the submission email address has not been set"
        return
      else
        raise StandardError, "Form id: #{form.id} is missing a submission email address"
      end
    end

    batch_service = AwsSesSubmissionBatchService.new(submissions_query: submissions, form:, mode:)

    message_id = send_email(batch_service, delivery, batch_begin_date)

    delivery.new_attempt!
    delivery.update!(
      delivery_reference: message_id,
    )

    CurrentJobLoggingAttributes.delivery_reference = delivery.delivery_reference
    log_batch_sent(delivery, batch_begin_date, mode)
    log_submissions_included_in_batch(delivery, batch_begin_date)
  end

private

  def send_email(batch_service, delivery, batch_begin_date)
    if delivery.daily?
      batch_service.send_daily_batch(date: batch_begin_date)
    elsif delivery.weekly?
      batch_service.send_weekly_batch(begin_date: batch_begin_date, end_date: batch_begin_date + 6.days)
    else
      raise StandardError, "Unexpected delivery schedule: #{delivery.delivery_schedule}"
    end
  end

  def log_batch_sent(delivery, batch_begin_date, mode)
    event_name = delivery.daily? ? "daily_batch_email_sent" : "weekly_batch_email_sent"
    EventLogger.log_form_event(event_name, {
      mode: mode.to_s,
      batch_begin_date: batch_begin_date,
      number_of_submissions: delivery.submissions.count,
    })
  end

  def log_submissions_included_in_batch(delivery, batch_begin_date)
    event_name = delivery.daily? ? "included_in_daily_batch_email" : "included_in_weekly_batch_email"
    delivery.submissions.each do |submission|
      EventLogger.log_form_event(event_name, {
        submission_reference: submission.reference,
        batch_begin_date: batch_begin_date,
      })
    end
  end
end
