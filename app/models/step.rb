class Step
  attr_accessor :form_document_step, :question

  GOTO_PAGE_ERROR_NAMES = %w[cannot_have_goto_page_before_routing_page goto_page_doesnt_exist].freeze

  def initialize(form_document_step:, question:)
    @form_document_step = form_document_step
    @question = question
  end

  alias_attribute :id, :page_id

  def page_id
    form_document_step&.id.to_s
  end

  def page_number
    form_document_step&.position
  end

  def next_step_slug
    form_document_step.has_next_page? ? form_document_step.next_page.to_s : CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG
  end

  def routing_conditions
    form_document_step.respond_to?(:routing_conditions) ? form_document_step.routing_conditions : []
  end

  def ==(other)
    other.class == self.class && other.state == state
  end

  def state
    instance_variables.map { |variable| instance_variable_get variable }
  end

  def save_to_store(answer_store)
    question.before_save
    return false unless question.errors.empty?

    answer_store.save_step(self, question.serializable_hash)
    self
  end

  def load_from_store(answer_store)
    attrs = answer_store.get_stored_answer(self)
    question.assign_attributes(attrs || {})
    self
  end

  def assign_question_attributes(params)
    question.assign_attributes(params)
  end

  def params
    question.attribute_names.concat([selection: []])
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

  def next_step_slug_after_routing
    if exit_page_condition_matches?
      return nil
    end

    if first_condition_default?
      return goto_condition_step_slug(routing_conditions.first)
    end

    if first_condition_matches?
      return goto_condition_step_slug(routing_conditions.first)
    end

    next_step_slug
  end

  def repeatable?
    false
  end

  def skipped?
    question.is_optional? && question.show_answer.blank?
  end

  def conditions_with_goto_errors
    routing_conditions.filter do |condition|
      condition.validation_errors.any? do |error|
        GOTO_PAGE_ERROR_NAMES.include? error.name
      end
    end
  end

  def has_exit_page_condition?
    return false unless routing_conditions&.first.respond_to?(:exit_page_markdown)

    routing_conditions.first.exit_page_markdown.is_a?(String)
  end

  def exit_page_condition_matches?
    first_condition_matches? && has_exit_page_condition?
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

  def goto_condition_step_slug(condition)
    if condition.goto_page_id.nil? && condition.skip_to_end
      CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG
    else
      condition.goto_page_id.to_s
    end
  end

  def first_condition_matches?
    return unless question.respond_to?(:selection)

    return question.selection == I18n.t("page.none_of_the_above") if routing_condition_none_of_the_above

    routing_conditions.any? && (routing_conditions.first.answer_value == question.selection)
  end

  def first_condition_default?
    routing_conditions.any? && routing_conditions.first.answer_value.blank?
  end

  def routing_condition_none_of_the_above
    routing_conditions.any? && routing_conditions.first.answer_value == :none_of_the_above.to_s
  end
end
