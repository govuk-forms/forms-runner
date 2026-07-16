class LogEventService
  def initialize(current_context, step, request, changing_answer, answers)
    @current_context = current_context
    @step = step
    @request = request
    @changing_answer = changing_answer
    @answers = answers
  end

  def self.log_form_start
    EventLogger.log_form_event("visit")
  end

  def self.log_submit(context, requested_email_confirmation:, preview:)
    if preview
      EventLogger.log_form_event("preview_submission")
    else
      # Logging to Splunk
      EventLogger.log_form_event("submission")

      EventLogger.log_form_event("requested_email_confirmation") if requested_email_confirmation

      # Logging to CloudWatch
      begin
        CloudWatchService.record_form_submission_metric(form_id: context.form.id)
      rescue StandardError => e
        Sentry.capture_exception(e)
      end
    end
  end

  def log_page_save
    EventLogger.log_page_event(log_event, @step.question.question_text, skipped_question?)
    if is_starting_form?
      begin
        CloudWatchService.record_form_start_metric(form_id: @current_context.form.id) # Logging to CloudWatch
      rescue StandardError => e
        Sentry.capture_exception(e)
      end
    end
  end

private

  def log_event
    page_optional = @step.question.is_optional? ? "optional" : "page"

    if @changing_answer
      "change_answer_#{page_optional}_save"
    elsif is_first_page?
      "first_#{page_optional}_save"
    else
      "#{page_optional}_save"
    end
  end

  def skipped_question?
    @step.question.is_optional? ? @answers.each_value.map.none?(&:present?) : nil
  end

  def is_starting_form?
    @current_context.completed_steps.empty?
  end

  def is_first_page?
    @current_context.form.start_page.to_s == @step.id
  end
end
