class Step
  attr_accessor :question
  private attr_reader :form_document_step

  class StoredAnswerMismatch < StandardError; end

  def initialize(form_document_step:, question:)
    @form_document_step = form_document_step
    @question = question
  end

  def ==(other)
    super ||
      other.instance_of?(self.class) &&
        other.id == id
  end

  delegate :answer_type, to: :form_document_step

  def id
    form_document_step&.id.to_s
  end

  def step_number
    form_document_step&.position
  end

  def next_step_slug
    form_document_step.next_step_id.present? ? form_document_step.next_step_id.to_s : CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG
  end

  def exit_pages
    @exit_pages ||=
      if form_document_step.respond_to?(:exit_pages)
        form_document_step.exit_pages.map { ExitPage.from_form_document(it) }
      else
        []
      end
  end

  def routing_conditions
    @routing_conditions ||=
      if form_document_step.respond_to?(:routing_conditions)
        form_document_step.routing_conditions.map { Condition.new(form_document_condition: it) }
      else
        []
      end
  end

  def save_to_store(answer_store)
    question.before_save
    return false unless question.errors.empty?

    answer_store.save_step(self, question.serializable_hash)
    self
  end

  def load_from_store(answer_store)
    attrs = answer_store.get_stored_answer(self)

    if attrs.is_a?(Array)
      raise StoredAnswerMismatch
    end

    begin
      question.assign_attributes(attrs || {})
    rescue ActiveModel::UnknownAttributeError
      raise StoredAnswerMismatch
    end

    self
  end

  def assign_question_attributes(params)
    question.assign_attributes(params)
  end

  def params
    question.attribute_names.concat([{ selection: [] }])
  end

  delegate :valid?, to: :question

  def clear_errors
    question.errors.clear
  end

  delegate :show_answer, :show_answer_in_email, :show_answer_in_csv, :question_text, :hint_text, :answer_settings, to: :question

  def show_answer_in_json(submission_reference:, is_s3_submission:)
    {
      question_id: form_document_step&.id,
      question_text: question_text,
      **question.show_answer_in_json(submission_reference:, is_s3_submission:),
    }
  end

  def end_page?
    next_step_slug.nil?
  end

  def matching_condition
    if first_condition_default?
      return routing_conditions.first
    end

    find_matching_condition
  end

  def next_step_slug_after_routing
    condition = matching_condition

    if condition.nil?
      next_step_slug
    elsif condition.exit_page?
      nil
    elsif condition.skip_to_end?
      CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG
    else
      condition.goto_page_id
    end
  end

  def repeatable?
    false
  end

  def skipped?
    question.is_optional? && question.show_answer.blank?
  end

  def has_exit_page_condition?
    routing_conditions.any?(&:exit_page?)
  end

  def exit_page_condition_matches?
    condition = find_matching_condition

    return false if condition.nil?

    condition.exit_page?
  end

  def answered_file_question?
    question.is_a?(Question::File) && question.file_uploaded?
  end

  def autocomplete_selection_question?
    question.is_a?(Question::Selection) && question.autocomplete_component?
  end

  def is_selection_with_none_of_the_above_answer?
    question.try(:show_none_of_the_above_question?)
  end

private

  def find_matching_condition
    return unless question.respond_to?(:selection)

    routing_conditions.find { it.match? question.selection }
  end

  def first_condition_default?
    routing_conditions.any? && routing_conditions.first.default?
  end
end
