class LoadFormProgressService
  def initialize(current_context:, user_id:)
    @current_context = current_context
    @user_id = user_id
  end

  def load!
    incomplete_submission = IncompleteSubmission.find_by(user_id: @user_id, form_id: @current_context.form.id)
    return nil unless incomplete_submission

    @current_context.load_answers(incomplete_submission.answers)
    @current_context.set_submission_reference(incomplete_submission.submission_reference)
    @current_context.add_locale(incomplete_submission.locale)

    incomplete_submission
  end
end
