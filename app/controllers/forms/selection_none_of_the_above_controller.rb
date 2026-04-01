module Forms
  class SelectionNoneOfTheAboveController < PageController
    before_action :redirect_if_not_show_none_of_the_above_question

    def show
      return redirect_to form_page_path(@form.id, @form.form_slug, current_context.next_step_slug) unless current_context.can_visit?(@step.id)

      setup_instance_vars_for_view
    end

    def save
      page_params = params.fetch(:question, {}).permit(*@step.params)
      @step.question.with_none_of_the_above_selected
      @step.assign_question_attributes(page_params)

      if current_context.save_step(@step)
        unless mode.preview?
          LogEventService.new(current_context, @step, request, changing_existing_answer, page_params).log_page_save
        end

        redirect_to next_page
      else
        setup_instance_vars_for_view
        render :show, status: :unprocessable_content
      end
    end

    def redirect_if_not_show_none_of_the_above_question
      unless @step.question.try(:has_none_of_the_above_question?) && @step.question.try(:autocomplete_component?)
        redirect_to form_page_path(@form.id, @form.form_slug, @step.id)
      end
    end

  private

    def setup_instance_vars_for_view
      @back_link = back_link
      @question_edit_link = question_edit_link
    end

    def back_link
      if changing_existing_answer
        check_your_answers_path(form_id: current_context.form.id)
      else
        form_page_path(@form.id, @form.form_slug, @step.id)
      end
    end
  end
end
