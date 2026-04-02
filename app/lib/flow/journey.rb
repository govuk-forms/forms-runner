module Flow
  ##
  # This class represents the journey taken by a form filler through a form.
  #
  # For a simple form (with no routing) there is only one possible set of
  # steps that a form filler can take, but for a form with routing there
  # may be some pages that the form filler never sees.
  #
  # Journey#completed_steps is an array of the steps that the form filler has
  # visited so far in the form, in the order defined by the form. If their
  # answer to a question step causes a routing rule to be applied, for
  # instance by skipping over the next two questions, only the questions in the
  # resulting route are included.
  #
  # Note: the completed_steps array is ordered, from start to last step
  # answered; if the form filler has not yet visited the form's first step, the
  # array will be empty.

  class Journey
    attr_reader :completed_steps

    def initialize(answer_store:, form:)
      @answer_store = answer_store
      @form = form
      @step_factory = StepFactory.new(form:)
      @completed_steps = generate_completed_steps

      populate_file_suffixes
    end

    def find_or_create(step_slug)
      step = completed_steps.find { |s| s.id == step_slug }
      step || @step_factory.create_step(step_slug)
    end

    def previous_step(step_slug)
      index = completed_steps.find_index { |step| step.id == step_slug }
      return nil if completed_steps.empty? || index&.zero?

      return completed_steps.last if index.nil?

      completed_steps[index - 1]
    end

    def next_step_slug
      return nil if completed_steps.last&.end_page?

      completed_steps.last&.next_step_slug_after_routing || @step_factory.start_step.id
    end

    def next_step
      return nil if completed_steps.last&.end_page?

      find_or_create(completed_steps.last&.next_step_slug_after_routing) || @step_factory.start_step
    end

    def can_visit?(step_slug)
      (completed_steps.map(&:id).include? step_slug) || step_slug == next_step_slug
    end

    def all_steps
      @form.form_document_steps.map { |form_document_step| find_or_create(form_document_step.id.to_s) }
    end

    def completed_file_upload_questions
      completed_steps
              .select { |step| step.question.is_a?(Question::File) && step.question.file_uploaded? }
              .map(&:question)
    end

    def populate_file_suffixes
      completed_file_upload_questions.each_with_index do |question, index|
        previous_completed_file_questions = completed_file_upload_questions.take(index)

        count = previous_completed_file_questions.filter {
          it.filename_after_reference_truncation == question.filename_after_reference_truncation
        }.count

        question.filename_suffix = count.zero? ? "" : "_#{count}"
      end
    end

  private

    def step_is_completed?(question_page_step)
      # A step has been completed if it is a question that has been answered.
      question_page_step.question.answered?
    end

    def generate_completed_steps
      each_step_with_routing.take_while do |step|
        step_is_completed?(step)
      end
    end

    def each_step_with_routing
      current_step = @step_factory.create_step(:_start)
      visited_step_slugs = []

      Enumerator.new do |yielder|
        loop do
          break if current_step.nil?
          break if current_step.is_a? CheckYourAnswersStep # CheckYourAnswers step signals end of steps

          # We need to load the answer into the step for next_page_with_routing to give the correct result.
          current_step = safe_load_from_store(current_step)

          next_step_slug = current_step.next_step_slug_after_routing

          # Prevent infinite loop if a route goes back on itself
          break if visited_step_slugs.include?(next_step_slug)

          yielder << current_step
          visited_step_slugs << current_step.id

          break if next_step_slug.nil?

          current_step = @step_factory.create_step(next_step_slug)
        end
      end
    end

    def safe_load_from_store(step)
      return step unless step.respond_to? :load_from_store # step may be a CheckYourAnswersStep without load_from_store method

      original_step = step.deep_dup # load_from_store method for RepeatableStep can fail with data half loaded

      begin
        step.load_from_store(@answer_store)
      rescue ActiveModel::UnknownAttributeError, ArgumentError
        original_step
      end
    end
  end
end
