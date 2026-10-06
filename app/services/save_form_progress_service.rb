class SaveFormProgressService
  def initialize(current_context:, user_id:)
    @current_context = current_context
    @user_id = user_id
  end

  def save
    saved = SavedAnswer.find_or_initialize_by(user_id: @user_id, form_id: @current_context.form.id)
    saved.form_version = @current_context.form.version
    saved.answers = @current_context.answers
    saved.save!
  end

private

  attr_reader :user_id, :current_context
end
