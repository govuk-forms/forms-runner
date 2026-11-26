module Forms
  class ContinueSavedFormController < BaseController
    before_action :redirect_if_save_and_return_disabled

    def new
      return load_saved_progress_and_redirect if auth_service.logged_in?

      auth_service.store_return_params(
        form: current_context.form,
        mode:,
        locale: locale_param,
        return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:continue_saved_form],
      )
    end

    def signed_in
      unless auth_service.logged_in? && auth_service.return_to == Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:continue_saved_form]
        return redirect_to(continue_saved_form_path(current_context.form.id, current_context.form.form_slug))
      end

      auth_service.clear_return_from_one_login
      load_saved_progress_and_redirect
    end

    def submit_not_found
      return redirect_to(continue_saved_form_path(current_context.form.id, current_context.form.form_slug)) unless auth_service.logged_in?

      @start_new_form_input = StartNewFormInput.new(start_new_form_input_params)
      return render(:not_found, status: :unprocessable_content) unless @start_new_form_input.valid?

      return sign_out_and_sign_in_again unless @start_new_form_input.start_new_form?

      current_context.start_new_form

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.form.start_page)
    end

  private

    def load_saved_progress_and_redirect
      incomplete_submission = LoadFormProgressService.new(current_context:, user_id: auth_service.sub, mode:).load!
      return redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.form.start_page) if incomplete_submission

      current_context.start_new_form

      @start_new_form_input = StartNewFormInput.new
      render :not_found, status: :not_found
    end

    def sign_out_and_sign_in_again
      auth_service.store_return_params(
        form: current_context.form,
        mode:,
        locale: locale_param,
        return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:sign_in_again_to_continue_saved_form],
      )

      EventLogger.log({ event: "sign_in_with_different_one_login_to_resume" })
      redirect_to auth_service.logout_redirect_uri(omniauth_logged_out_url), allow_other_host: true
    end

    def start_new_form_input_params
      params.fetch(:start_new_form_input, ActionController::Parameters.new).permit(:start_new_form)
    end

    def redirect_if_save_and_return_disabled
      return if current_context.form.save_and_return_enabled?

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)
    end
  end
end
