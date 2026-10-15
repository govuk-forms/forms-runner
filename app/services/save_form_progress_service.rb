class SaveFormProgressService
  def initialize(current_context:, user_id:, mode:)
    @current_context = current_context
    @user_id = user_id
    @mode = mode
  end

  def save!
    saved = IncompleteSubmission.find_or_initialize_by(user_id: @user_id, form_id: @current_context.form.id)
    saved.form_version = @current_context.form.version
    saved.answers = @current_context.answers
    saved.locale = @current_context.submission_locale
    saved.mode = @mode.to_s
    saved.save!
  end
end
