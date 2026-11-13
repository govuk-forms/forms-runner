module Forms
  class SaveProgressController < BaseController
    before_action :redirect_if_save_and_return_disabled, except: %i[sign_out save_progress_and_sign_out]

    def new
      unless auth_service.logged_in?
        auth_service.store_return_params(
          form: current_context.form,
          mode:,
          locale: locale_param,
          return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:save_and_return],
        )
        return
      end

      @one_login_email = auth_service.email
      saved = find_saved_progress
      render_already_saved(saved) if saved
    end

    def after_sign_in
      unless auth_service.logged_in? && auth_service.return_to == Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:save_and_return]
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

      return redirect_to(form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)) if @already_saved_input.keep_saved?

      save_progress_and_redirect
    end

    def show
      saved = find_saved_progress
      return redirect_to(save_progress_path(current_context.form.id, current_context.form.form_slug)) unless saved

      @one_login_email = auth_service.email
      @deletion_date = (saved.updated_at + 30.days).strftime("%-d %B %Y")
    end

    def sign_out
      return head :unauthorized unless auth_service.logged_in?

      return redirect_to omniauth_logout_path(mode: nil), status: 307 unless current_context.form.save_and_return_enabled?

      saved = find_saved_progress
      return redirect_to omniauth_logout_path(mode: nil), status: 307 unless saved

      @already_saved_input ||= AlreadySavedSignOutInput.new
      @last_saved_date = saved.updated_at.strftime("%-d %B %Y")
      @last_saved_time = saved.updated_at.strftime("%l:%M%P").strip

      render :already_saved_sign_out
    end

    def save_progress_and_sign_out
      return head :unauthorized unless auth_service.logged_in?

      return redirect_to omniauth_logout_path(mode: nil), status: 307 unless current_context.form.save_and_return_enabled?

      already_saved_input_params = params.fetch(:already_saved_sign_out_input, ActionController::Parameters.new).permit(:already_saved)
      @already_saved_input = AlreadySavedSignOutInput.new(already_saved_input_params)

      unless @already_saved_input.valid?
        saved = find_saved_progress
        @last_saved_date = saved.updated_at.strftime("%-d %B %Y")
        @last_saved_time = saved.updated_at.strftime("%l:%M%P").strip
        return render :already_saved_sign_out, status: :unprocessable_content
      end

      return redirect_to(form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)) if @already_saved_input.keep_saved?

      return redirect_to omniauth_logout_path(mode: nil), status: 307 if @already_saved_input.sign_out_without_saving?

      save_progress_and_redirect
    end

  private

    def render_already_saved(saved, status: :ok)
      @already_saved_input ||= AlreadySavedInput.new
      @last_saved_date = saved.updated_at.strftime("%-d %B %Y")
      @last_saved_time = saved.updated_at.strftime("%l:%M%P").strip
      render :already_saved, status:
    end

    def already_saved_input_params
      params.fetch(:already_saved_input, ActionController::Parameters.new).permit(:already_saved)
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
