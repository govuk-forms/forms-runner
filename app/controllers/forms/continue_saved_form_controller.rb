module Forms
  class ContinueSavedFormController < BaseController
    before_action :redirect_if_save_and_return_disabled

    def new
      unless auth_service.logged_in?
        auth_service.store_return_params(
          form: current_context.form,
          mode:,
          locale: locale_param,
          return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:continue_saved_form],
        )
        return
      end

      load_saved_progress_and_redirect
    end

    def signed_in
      unless auth_service.logged_in? && auth_service.return_to == Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:continue_saved_form]
        return redirect_to(continue_saved_form_path(current_context.form.id, current_context.form.form_slug))
      end

      auth_service.clear_return_from_one_login
      load_saved_progress_and_redirect
    end

  private

    def load_saved_progress_and_redirect
      incomplete_submission = LoadFormProgressService.new(current_context:, user_id: auth_service.sub).load!
      return render :not_found, status: :not_found unless incomplete_submission

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.form.start_page)
    end

    def redirect_if_save_and_return_disabled
      return if current_context.form.save_and_return_enabled?

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)
    end
  end
end
