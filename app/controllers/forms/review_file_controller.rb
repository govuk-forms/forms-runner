module Forms
  class ReviewFileController < StepController
    before_action :redirect_if_not_answered_file_question

    def show
      back_link(@step.id)
      @remove_file_confirmation_url = remove_file_confirmation_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: @step.id, changing_existing_answer:)
      @continue_url = review_file_continue_path(form_id: @form.id, form_slug: @form.form_slug, step_slug: @step.id, changing_existing_answer:)
    end

    def continue
      redirect_to next_page
    end
  end
end
