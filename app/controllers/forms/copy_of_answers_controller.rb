module Forms
  class CopyOfAnswersController < BaseController
    before_action :redirect_if_feature_disabled

    def show
      return redirect_to form_page_path(current_context.form.id, current_context.form.form_slug, current_context.next_step_slug) unless can_visit_copy_of_answers?

      @back_link = back_link
      @copy_of_answers_input = CopyOfAnswersInput.new
    end

    def save
      @copy_of_answers_input = CopyOfAnswersInput.new(copy_of_answers_params)

      unless @copy_of_answers_input.valid?
        @back_link = back_link
        return render :show, status: :unprocessable_content
      end

      current_context.save_copy_of_answers_preference(@copy_of_answers_input.wants_copy?)

      redirect_to check_your_answers_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug)
    end

  private

    def copy_of_answers_params
      params.require(:copy_of_answers_input).permit(:copy_of_answers)
    end

    def can_visit_copy_of_answers?
      current_context.can_visit?(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)
    end

    def back_link
      previous_step = current_context.previous_step(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)

      if previous_step.present?
        previous_step.repeatable? ? add_another_answer_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug, step_slug: previous_step.id) : form_page_path(current_context.form.id, current_context.form.form_slug, previous_step.id)
      end
    end

    def redirect_if_feature_disabled
      return if FeatureService.enabled?("filler_answer_email_enabled")

      redirect_to check_your_answers_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug)
    end
  end
end
