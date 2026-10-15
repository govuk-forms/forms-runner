module Forms
  class SaveProgressController < BaseController
    before_action :redirect_if_save_and_return_disabled

    def new
      @one_login_email = auth_service.email
      return if auth_service.logged_in?

      auth_service.store_return_params(
        form: current_context.form,
        mode:,
        locale: locale_param,
        return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:save_and_return],
      )
    end

    def create
      return redirect_to(save_progress_path(current_context.form.id, current_context.form.form_slug)) unless auth_service.logged_in?

      SaveFormProgressService.new(current_context:, user_id: auth_service.sub).save!

      redirect_to progress_saved_path(current_context.form.id, current_context.form.form_slug)
    end

    def show
      @one_login_email = auth_service.email
      saved = IncompleteSubmission.find_by(user_id: auth_service.sub, form_id: current_context.form.id)
      @deletion_date = (saved.updated_at + 30.days).strftime("%-d %B %Y")
    end

  private

    def redirect_if_save_and_return_disabled
      return if current_context.form.save_and_return_enabled?

      redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug)
    end
  end
end
