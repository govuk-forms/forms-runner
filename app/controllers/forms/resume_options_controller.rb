module Forms
  class ResumeOptionsController < BaseController
    before_action :back_to_start
    def show; end

  private

    def back_to_start
      unless @current_context.form.save_and_return_enabled?
        redirect_to form_step_path(@current_context.form.id,
                                   @current_context.form.form_slug,
                                   @current_context.form.start_page)
      end
    end
  end
end
