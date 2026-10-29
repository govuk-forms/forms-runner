module Forms
  class ResumeOptionsController < BaseController
    before_action :back_to_start
    def show
      @resume_options_input = ResumeOptionsInput.new
    end

    def continue
      @resume_options_input = ResumeOptionsInput.new(resume_options_params)

      unless @resume_options_input.valid?
        return render :show, status: :unprocessable_entity
      end

      return redirect_to form_step_path(current_context.form.id, current_context.form.form_slug, current_context.form.start_page) unless @resume_options_input.continue_saved?

      redirect_to resume_progress_path(form_id: @current_context.form.id, form_slug: @current_context.form.form_slug)
    end

  private

    def back_to_start
      unless @current_context.form.save_and_return_enabled?
        redirect_to form_step_path(@current_context.form.id,
                                   @current_context.form.form_slug,
                                   @current_context.form.start_page)
      end
    end

    def resume_options_params
      params.require(:resume_options_input).permit(:resume_options)
    end
  end
end
