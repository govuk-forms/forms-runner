module Forms
  class ExitPagesController < StepController
    def set_request_logging_attributes
      super
      CurrentRequestLoggingAttributes.exit_page_id = params[:exit_page_id]
    end

    def show
      return redirect_to form_step_path(@form.id, @form.form_slug, current_context.next_step_slug) unless current_context.can_visit?(@step.id)

      @condition = @step.matching_condition

      return redirect_to form_step_path(@form.id, @form.form_slug, current_context.next_step_slug) unless @condition&.exit_page?

      @back_link = form_step_path(@form.id, @form.form_slug, @step.id)

      if @condition.new_style_exit_page?
        unless @condition.exit_page_id == params[:exit_page_id]
          return redirect_to exit_page_path(@form.id, @form.form_slug, @step.id, @condition.exit_page_id)
        end

        @exit_page = @step.exit_pages.find { it.id == @condition.exit_page_id }
        raise KeyError, "Couldn't find ExitPage with id=#{@condition.exit_page_id}" if @exit_page.nil?
      else
        if params[:exit_page_id]
          raise ActionController::RoutingError, "Exit page ID param provided for form with old-style exit pages"
        end

        @exit_page = ExitPage.new(
          id: nil,
          heading: @condition.exit_page_heading,
          markdown: @condition.exit_page_markdown,
        )
      end
    end
  end
end
