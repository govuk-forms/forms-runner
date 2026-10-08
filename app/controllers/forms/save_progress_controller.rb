module Forms
  class SaveProgressController < BaseController
    before_action :redirect_if_save_and_return_disabled

    def new
      if auth_service.logged_in?
        SaveFormProgressService.new(current_context:, user_id: auth_service.sub).save!

        redirect_to progress_saved_path(current_context.form.id, current_context.form.form_slug)
      else
        auth_service.store_return_params(
          form: current_context.form,
          mode:,
          locale: locale_param,
          return_to: "save_progress",
        )
      end
    end

    def show; end

  private

    def redirect_if_save_and_return_disabled
      return if current_context.form.save_and_return_enabled?

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)
    end
  end
end
