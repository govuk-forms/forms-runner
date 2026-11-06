class SaveFormProgressService
  def initialize(current_context:, user_id:, mode:, email:)
    @current_context = current_context
    @user_id = user_id
    @mode = mode
    @email = email
  end

  def save!
    generate_submission_uuid_if_missing

    incomplete_submission = IncompleteSubmission.find_or_initialize_by(user_id: @user_id, form_id: @current_context.form.id, mode: @mode.to_s)
    incomplete_submission.form_version = @current_context.form.version
    incomplete_submission.answers = @current_context.answers
    incomplete_submission.locale = @current_context.submission_locale
    incomplete_submission.submission_uuid = @current_context.get_submission_uuid
    incomplete_submission.updated_at = Time.current
    save_with_unique_submission_uuid!(incomplete_submission)

    enqueue_send_email_job(incomplete_submission)
  end

private

  # The submission_uuid in the user's session is not scoped by mode. If it has already been used for an
  # IncompleteSubmission for a different mode or GOV.UK One Login user, generate a new one so we don't conflict.
  def save_with_unique_submission_uuid!(incomplete_submission)
    incomplete_submission.save!
  rescue ActiveRecord::RecordNotUnique => e
    raise unless e.message.include?("submission_uuid")

    previous_submission_uuid = incomplete_submission.submission_uuid
    CurrentRequestLoggingAttributes.submission_uuid = @current_context.generate_submission_uuid
    Rails.logger.info("Regenerated submission_uuid because it is already in use for a different incomplete submission",
                      { previous_submission_uuid: })

    incomplete_submission.submission_uuid = @current_context.get_submission_uuid
    incomplete_submission.save!
  end

  # Only needed for sessions that were in flight when submission_uuid was introduced, as they won't have one.
  # This can be removed once those sessions have expired.
  def generate_submission_uuid_if_missing
    return if @current_context.get_submission_uuid.present?

    CurrentRequestLoggingAttributes.submission_uuid = @current_context.generate_submission_uuid
  end

  def enqueue_send_email_job(incomplete_submission)
    SendProgressSavedEmailJob.perform_later(incomplete_submission: incomplete_submission, email_address: @email) do |job|
      next if job.successfully_enqueued?

      message_suffix = ": #{job.enqueue_error&.message}" if job.enqueue_error
      raise StandardError, "Failed to enqueue progress saved email for submission #{incomplete_submission.submission_uuid}#{message_suffix}"
    end
  end
end
