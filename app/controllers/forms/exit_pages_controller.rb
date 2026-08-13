module Forms
  class ExitPagesController < StepController
    def show
      unless current_context.can_visit?(@step.id) && @step.exit_page_condition_matches?
        return redirect_to form_step_path(@form.id, @form.form_slug, current_context.next_step_slug)
      end

      @back_link = form_step_path(@form.id, @form.form_slug, @step.id)
      @condition = @step.routing_conditions.first
      @exit_page = @step.exit_pages.find { it.id == @condition.exit_page_id }
      raise KeyError, "Couldn't find ExitPage with id=#{@condition.exit_page_id}" if @exit_page.nil?
    end
  end
end
