module Forms
  class ExitPagesController < StepController
    def show
      unless current_context.can_visit?(@step.id) && @step.exit_page_condition_matches?
        return redirect_to form_step_path(@form.id, @form.form_slug, current_context.next_step_slug)
      end

      @back_link = form_step_path(@form.id, @form.form_slug, @step.id)
      @condition = @step.routing_conditions.first

      if @condition.new_style_exit_page?
        @exit_page = @step.exit_pages.find { it.id == @condition.exit_page_id }
        raise KeyError, "Couldn't find ExitPage with id=#{@condition.exit_page_id}" if @exit_page.nil?
      else
        @exit_page = ExitPage.new(
          id: nil,
          heading: @condition.exit_page_heading,
          markdown: @condition.exit_page_markdown,
        )
      end
    end
  end
end
