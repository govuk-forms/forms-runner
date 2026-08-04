class Condition
  private attr_reader :form_document_condition

  delegate(
    :id,
    :answer_value,
    :exit_page_heading,
    :exit_page_markdown,
    :validation_errors,
    to: :form_document_condition,
  )

  def initialize(form_document_condition:)
    @form_document_condition = form_document_condition
  end

  def ==(other)
    super ||
      other.instance_of?(self.class) &&
        other.id == id
  end

  def check_page_id
    form_document_condition.check_page_id.to_s
  end

  def goto_page_id
    form_document_condition.goto_page_id.to_s
  end

  def match?(answer_value)
    return answer_value == Question::Selection::NONE_OF_THE_ABOVE_VALUE if self.answer_value == :none_of_the_above.to_s

    self.answer_value == answer_value
  end

  def exit_page?
    return false unless form_document_condition.respond_to?(:exit_page_markdown)

    form_document_condition.exit_page_markdown.is_a?(String)
  end

  def skip_to_end?
    form_document_condition.goto_page_id.nil? && form_document_condition.skip_to_end
  end
end
