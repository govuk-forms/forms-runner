module Forms
  class ExitPagesController < StepController
    def show
      return redirect_to form_page_path(@form.id, @form.form_slug, current_context.next_step_slug) unless current_context.can_visit?(@step.id)

      @back_link = form_page_path(@form.id, @form.form_slug, @step.id)
      @condition = @step.routing_conditions.first
    end
  end
end
