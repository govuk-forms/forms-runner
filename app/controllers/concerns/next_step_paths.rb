module NextStepPaths
  extend ActiveSupport::Concern

private

  def next_step_path(step)
    return exit_page_path_for(step) if step.exit_page_condition_matches?

    if should_show_add_another?(step)
      return add_another_answer_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: step.id)
    end

    next_step_in_form_path(step)
  end

  def next_step_in_form_path(step)
    if step.next_step_slug_after_routing == CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG
      if @form.copy_of_answers_enabled?
        copy_of_answers_path(form_id: @form.id, form_slug: @form.form_slug)
      else
        check_answers_path
      end
    else
      form_step_path(@form.id, @form.form_slug, step.next_step_slug_after_routing)
    end
  end

  def exit_page_path_for(step)
    exit_page_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: step.id, exit_page_id: step.matching_condition.exit_page_id)
  end

  def check_answers_path
    check_your_answers_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug)
  end

  def should_show_add_another?(step)
    step.repeatable? && !step.skipped?
  end
end
