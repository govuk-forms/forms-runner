module Flow
  class StepFactory
    START_PAGE = "_start".freeze

    class PageNotFoundError < StandardError
      def initialize(msg = "Page not found.")
        super
      end
    end

    def initialize(form:)
      @form = form
    end

    def create_step(page_slug_or_start)
      # Normalize the id or constant passed in
      page_slug = page_slug_or_start.to_s == START_PAGE ? @form.start_page : page_slug_or_start
      page_slug = page_slug.to_s

      return CheckYourAnswersStep.new if page_slug == CheckYourAnswersStep::CHECK_YOUR_ANSWERS_PAGE_SLUG

      # for now, we use the step id as slug
      form_document_step = @form.form_document_steps.find { |s| s.id.to_s == page_slug }
      raise PageNotFoundError, "Can't find form_document_step #{page_slug}" if form_document_step.nil?

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
