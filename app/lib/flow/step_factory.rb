module Flow
  class StepFactory
    include Flow::Errors

    START_PAGE = "_start".freeze

    def initialize(form:)
      @form = form
    end

    def create_step(step_slug_or_start)
      # Normalize the id or constant passed in
      step_slug = step_slug_or_start.to_s == START_PAGE ? @form.start_page : step_slug_or_start
      step_slug = step_slug.to_s

      return CheckYourAnswersStep.new if step_slug == CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG

      # for now, we use the step id as slug
      form_document_step = @form.form_document_steps.find { |s| s.id.to_s == step_slug }
      raise StepNotFoundError, "Can't find step #{step_slug}" if form_document_step.nil?

      question = QuestionRegister.from_form_document_step(form_document_step)

      step_class(form_document_step).new(question:, form_document_step:)
    end

    def start_step
      create_step(START_PAGE)
    end

  private

    def step_class(form_document_step)
      form_document_step.repeatable? ? RepeatableStep : Step
    end
  end
end
