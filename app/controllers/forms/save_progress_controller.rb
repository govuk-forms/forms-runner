module Forms
  class SaveProgressController < BaseController
    include NextStepPaths

    before_action :redirect_if_save_and_return_disabled

    def new
      @back_link = continue_path

      return render_signed_in if auth_service.logged_in?

      auth_service.store_return_params(
        form: current_context.form,
        mode:,
        locale: locale_param,
        return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:save_progress],
      )
    end

    def after_sign_in
      unless auth_service.logged_in? && auth_service.return_to == Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:save_progress]
        return redirect_to(save_progress_path(current_context.form.id, current_context.form.form_slug))
      end

      auth_service.clear_return_from_one_login

      saved = find_saved_progress
      return render_already_saved(saved) if saved

      save_progress_and_redirect
    end

    def create
      return redirect_to(save_progress_path(current_context.form.id, current_context.form.form_slug)) unless auth_service.logged_in?

      saved = find_saved_progress
      return render_already_saved(saved) if saved

      save_progress_and_redirect
    end

    def overwrite
      return redirect_to(save_progress_path(current_context.form.id, current_context.form.form_slug)) unless auth_service.logged_in?

      @already_saved_input = AlreadySavedInput.new(already_saved_input_params)
      unless @already_saved_input.valid?
        return render_already_saved(find_saved_progress, status: :unprocessable_content)
      end

      return redirect_to(continue_path) if @already_saved_input.keep_saved?

      save_progress_and_redirect
    end

    def show
      saved = find_saved_progress
      return redirect_to(save_progress_path(current_context.form.id, current_context.form.form_slug)) unless saved

      @one_login_email = auth_service.email
      @deletion_date = saved.updated_at + 30.days
      @continue_path = continue_path
    end

  private

    def continue_path
      last_completed_step = current_context.completed_steps.last
      return form_step_path(@form.id, @form.form_slug, current_context.next_step_slug) if last_completed_step.nil?

      next_step_path(last_completed_step)
    end

    def render_already_saved(saved, status: :ok)
      @back_link = continue_path
      @already_saved_input ||= AlreadySavedInput.new
      @last_saved_at = saved.updated_at
      render :already_saved, status:
    end

    def already_saved_input_params
      params.fetch(:already_saved_input, ActionController::Parameters.new).permit(:already_saved)
    end

    def render_signed_in(status: :ok)
      @back_link = continue_path
      @one_login_email = auth_service.email
      @continue_with_one_login_input ||= ContinueWithOneLoginInput.new
      render :signed_in, status:
    end

    def save_progress_and_redirect
      SaveFormProgressService.new(current_context:, user_id: auth_service.sub, mode:, email: auth_service.email).save!

      redirect_to progress_saved_path(current_context.form.id, current_context.form.form_slug)
    end

    def find_saved_progress
      IncompleteSubmission.find_by(user_id: auth_service.sub, form_id: current_context.form.id, mode: mode.to_s)
    end

    def redirect_if_save_and_return_disabled
      return if current_context.form.save_and_return_enabled?

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)
    end
  end
end
