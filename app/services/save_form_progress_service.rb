class SaveFormProgressService
  def initialize(current_context:, user_id:, mode:, email:)
    @current_context = current_context
    @user_id = user_id
    @mode = mode
    @email = email
  end

  def save!
    incomplete_submission = IncompleteSubmission.find_or_initialize_by(user_id: @user_id, form_id: @current_context.form.id)
    incomplete_submission.form_version = @current_context.form.version
    incomplete_submission.answers = @current_context.answers
    incomplete_submission.locale = @current_context.submission_locale
    incomplete_submission.mode = @mode.to_s
    incomplete_submission.submission_reference = @current_context.get_submission_reference
    incomplete_submission.save!

    enqueue_send_email_job(incomplete_submission)
  end

private

  def enqueue_send_email_job(incomplete_submission)
    SendProgressSavedEmailJob.perform_later(incomplete_submission: incomplete_submission, email_address: @email) do |job|
      next if job.successfully_enqueued?

      message_suffix = ": #{job.enqueue_error&.message}" if job.enqueue_error
      raise StandardError, "Failed to enqueue progress saved email for reference #{incomplete_submission.submission_reference}#{message_suffix}"
    end
  end
end
