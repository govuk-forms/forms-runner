class RepeatableStep < Step
  include ActionView::Helpers::SanitizeHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::OutputSafetyHelper

  class AnswerIndexError < IndexError; end

  MAX_ANSWERS = 50

  attr_accessor :answer_index, :questions

  def initialize(...)
    super
    @questions = [@question.dup]
  end

  def repeatable?
    true
  end

  def save_to_store(answer_store)
    answer_store.save_step(self, @questions.map(&:serializable_hash))
    self
  end

  def load_from_store(answer_store)
    question_attrs = answer_store.get_stored_answer(self)

    unless question_attrs.is_a?(Array)
      raise ArgumentError
    end

    @questions = question_attrs.map do |attrs|
      q = @question.dup
      q.assign_attributes(attrs || {})
      q
    end

    self
  end

  def question
    return questions.first if answer_index.blank?

    if questions.length + 1 == answer_index
      return add_blank_answer
    end

    questions.fetch(answer_index - 1)
  rescue IndexError
    raise AnswerIndexError
  end

  def next_answer_index
    questions.length + 1
  end

  def max_answers?
    questions.length >= MAX_ANSWERS
  end

  def valid?(context = nil)
    questions.all? { |q| q.valid?(context) }
  end

  def show_answer
    answers = questions.map(&:show_answer).compact_blank

    if answers.present?
      content_tag(:ol, class: "govuk-list govuk-list--number") do
        safe_join(
          answers.map do |answer|
            content_tag(:li, sanitize(answer))
          end,
        )
      end
    end
  end

  def show_answer_in_email(submission_reference:)
    questions.map.with_index(1) { |question, index|
      "#{index}. #{question.show_answer_in_email(submission_reference:)}"
    }.join("\n\n")
  end

  def show_answer_in_csv(submission_reference:, is_s3_submission:)
    header_values_hash = {}

    if questions.one? && questions.first.show_answer.blank?
      header_values_hash = question.show_answer_in_csv(submission_reference:, is_s3_submission:)
    else
      questions.each do |question|
        question.show_answer_in_csv(submission_reference:, is_s3_submission:).each do |header, value|
          header_values_hash[header] ||= []
          header_values_hash[header] << "Answer: #{value}"
        end
      end

      header_values_hash.transform_values! { |answers| answers.join("\n") }
    end

    header_values_hash
  end

  def show_answer_in_json(submission_reference:, is_s3_submission:)
    answer_hash = questions.first.show_answer_in_json.keys.index_with { [] }

    unless questions.one? && questions.first.show_answer.blank?
      questions.each do |question|
        question.show_answer_in_json(submission_reference:, is_s3_submission:).each do |key, value|
          answer_hash[key] << value
        end
      end
    end

    {
      question_id: form_document_step&.id,
      question_text: form_document_step.question_text,
      can_have_multiple_answers: true,
      **answer_hash,
    }
  end

  def remove_answer(answer_index)
    questions.delete_at(answer_index - 1)
    if questions.empty?
      add_blank_answer
    end
  end

  def min_answers?
    min_answers = @question.is_optional? ? 0 : 1

    questions.length <= min_answers
  end

private

  def add_blank_answer
    questions << @question.dup

    questions[answer_index - 1]
  end
end
