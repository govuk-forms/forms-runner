module Forms
  class PageController < BaseController
    before_action :prepare_step, :set_request_logging_attributes, :changing_existing_answer, :check_goto_page_routing_error

    def set_request_logging_attributes
      super
      CurrentRequestLoggingAttributes.question_number = @step.page_number if @step&.page_number
      CurrentRequestLoggingAttributes.answer_type = @step&.form_document_step&.answer_type if @step&.form_document_step&.answer_type
    end

    def show
      return redirect_to form_page_path(@form.id, @form.form_slug, current_context.next_step_slug) unless current_context.can_visit?(@step.id)
      return redirect_to review_file_page if @step.answered_file_question?

      setup_instance_vars_for_view
    end

    def change
      return redirect_to form_page_path(@form.id, @form.form_slug, current_context.next_step_slug) unless current_context.can_visit?(@step.id)
      return redirect_to review_file_page if @step.answered_file_question?

      setup_instance_vars_for_view
      render :show
    end

    def save
      page_params = params.fetch(:question, {}).permit(*@step.params)
      @step.assign_question_attributes(page_params)

      current_context.clear_submission_details if is_first_page?

      validation_context = @step.autocomplete_selection_question? ? :skip_none_of_the_above_question_validation : nil
      if current_context.save_step(@step, context: validation_context, locale:)
        # Redirect before logging when the question has multiple pages so that we don't send multiple form started
        # metrics to CloudWatch if this is the first question.
        return redirect_to selection_none_of_the_above_page if redirect_to_none_of_the_above_page?

        unless mode.preview?
          LogEventService.new(current_context, @step, request, changing_existing_answer, page_params).log_page_save
        end

        redirect_post_save
      else
        setup_instance_vars_for_view
        render :show, status: :unprocessable_content
      end
    end

  private

    def prepare_step
      step_slug = params.require(:step_slug)
      begin
        @step = current_context.find_or_create(step_slug)
      rescue Flow::StepFactory::StepNotFoundError
        return redirect_to form_page_path(@form.id, @form.form_slug, current_context.next_step_slug)
      end

      if @step.respond_to?(:answer_index)
        @step.answer_index = answer_index
      end

      @support_details = current_context.support_details
    end

    def answer_index
      params.fetch(:answer_index, 1).to_i
    end

    def setup_instance_vars_for_view
      @question_edit_link = question_edit_link
      @save_url = save_url
      @back_link = back_link(@step.id)
    end

    def question_edit_link
      "#{Settings.forms_admin.base_url}/forms/#{@form.id}/pages-by-external-id/#{@step.id}/edit-question"
    end

    def save_url
      save_form_page_path(@form.id, @form.form_slug, @step.id, changing_existing_answer: @changing_existing_answer, answer_index:)
    end

    def changing_existing_answer
      @changing_existing_answer = ActiveModel::Type::Boolean.new.cast(params[:changing_existing_answer])
    end

    def back_link(step_slug)
      return check_your_answers_path(form_id: current_context.form.id) if changing_existing_answer

      previous_step = current_context.previous_step(step_slug)
      return nil unless previous_step

      if previous_step.repeatable?
        add_another_answer_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug, step_slug: previous_step.id)
      else
        form_page_path(@form.id, @form.form_slug, previous_step.page_id)
      end
    end

    def redirect_post_save
      return redirect_to review_file_page, success: t("banner.success.file_uploaded") if @step.answered_file_question?
      return redirect_to exit_page_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: @step.id) if @step.exit_page_condition_matches?

      redirect_to next_page
    end

    def redirect_if_not_answered_file_question
      unless @step.answered_file_question?
        redirect_to form_page_path(@form.id, @form.form_slug, @step.id)
      end
    end

    def redirect_to_none_of_the_above_page?
      @step.autocomplete_selection_question? && @step.question.show_none_of_the_above_question?
    end

    def review_file_page
      review_file_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: @step.id, changing_existing_answer:)
    end

    def selection_none_of_the_above_page
      selection_none_of_the_above_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: @step.id)
    end

    def next_page
      if changing_existing_answer
        return next_step_changing
      end

      next_step_path
    end

    def next_step_path
      if should_show_add_another?(@step)
        return add_another_answer_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: @step.id)
      end

      next_step_in_form_path
    end

    def next_step_changing
      if should_show_add_another?(@step)
        return change_add_another_answer_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: @step.id)
      end

      check_answers_path
    end

    def next_step_in_form_path
      if @step.next_step_slug_after_routing == CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG
        if FeatureService.enabled?("filler_answer_email_enabled")
          copy_of_answers_path(form_id: @form.id, form_slug: @form.form_slug)
        else
          check_answers_path
        end
      else
        form_page_path(@form.id, @form.form_slug, @step.next_step_slug_after_routing)
      end
    end

    def check_answers_path
      check_your_answers_path(form_id: current_context.form.id, form_slug: current_context.form.form_slug)
    end

    def should_show_add_another?(step)
      step.repeatable? && !step.skipped?
    end

    def check_goto_page_routing_error
      return if @step.conditions_with_goto_errors.blank?

      first_condition_with_error = @step.conditions_with_goto_errors.first

      first_goto_error_name = first_condition_with_error.validation_errors.find { |error|
        Step::GOTO_PAGE_ERROR_NAMES.include?(error.name)
      }.name

      event_name = if first_goto_error_name == "cannot_have_goto_page_before_routing_page"
                     "goto_page_before_routing_page_error"
                   else
                     "goto_page_doesnt_exist_error"
                   end

      EventLogger.log_page_event(event_name, @step.question.question_text, nil)

      routes_page_id = first_condition_with_error.check_page_id
      routes_page = @current_context.find_or_create(routes_page_id)

      render template: "errors/goto_page_routing_error", locals: {
        error_name: first_goto_error_name,
        link_url: admin_edit_condition_url(@form.id, routes_page_id),
        question_number: routes_page.page_number,
      }, status: :unprocessable_content
    end

    def admin_edit_condition_url(form_id, page_id)
      "#{Settings.forms_admin.base_url}/forms/#{form_id}/pages-by-external-id/#{page_id}/routes"
    end

    def is_first_page?
      current_context.form.start_page.to_s == @step.id
    end
  end
end
