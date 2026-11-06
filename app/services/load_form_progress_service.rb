class LoadFormProgressService
  def initialize(current_context:, user_id:, mode:)
    @current_context = current_context
    @user_id = user_id
    @mode = mode
  end

  def load!
    incomplete_submission = IncompleteSubmission.find_by(user_id: @user_id, form_id: @current_context.form.id, mode: @mode.to_s)
    return nil unless incomplete_submission

    @current_context.clear
    @current_context.clear_submission_details

    @current_context.load_answers(incomplete_submission.answers)
    @current_context.add_locale(incomplete_submission.locale)

    @current_context.set_submission_uuid(incomplete_submission.submission_uuid)
    CurrentRequestLoggingAttributes.submission_uuid = incomplete_submission.submission_uuid

    incomplete_submission
  end
end
