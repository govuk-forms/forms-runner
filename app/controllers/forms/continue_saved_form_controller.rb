module Forms
  class ContinueSavedFormController < BaseController
    before_action :redirect_if_save_and_return_disabled

    def new
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
