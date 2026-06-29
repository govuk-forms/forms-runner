class SesEmailFormatter
  include EmailFormatHelper

  H_RULE = '<hr style="border: 0; height: 1px; background: #B1B4B6; Margin: 30px 0 30px 0;">'.freeze
  H_RULE_PLAIN_TEXT = "\n\n---\n\n".freeze

  class FormattingError < StandardError; end

  def initialize(submission_reference:, steps:, confirmation_email:)
    @submission_reference = submission_reference
    @steps = steps
    @confirmation_email = confirmation_email
  end

  def build_question_answers_section_markdown(heading_level: 3)
    @steps.map { |step|
      [prep_question_title_markdown(step, heading_level),
       prep_answer_text_markdown(step)].join("\n\n")
    }.join(H_RULE_PLAIN_TEXT)
  end

private

  def prep_question_title_markdown(step, heading_level)
    case heading_level
    when 3
      "### #{step.question.question_text}"
    when 4
      "#### #{step.question.question_text}"
    else
      raise FormattingError, "unsupported heading level: #{heading_level}"
    end
  end

  def prep_answer_text_markdown(step)
    if step.is_selection_with_none_of_the_above_answer?
      prep_none_of_the_above_answer_text_markdown(step)
    else
      prep_answer_text(step)
    end
  rescue StandardError
    raise FormattingError, "could not format answer for question step #{step.id}"
  end

  def prep_none_of_the_above_answer_text_markdown(step)
    [
      prep_answer_text(step),
      "#### #{step.question.none_of_the_above_question_text}",
      prep_none_of_the_above_answer_markdown(step),
    ].join("\n\n")
  end

  def prep_answer_text(step)
    answer = step.show_answer_in_email(submission_reference: @submission_reference, confirmation_email: @confirmation_email)

    return skipped_question_text if answer.blank?

    sanitize(answer)
  rescue StandardError
    raise FormattingError, "could not format answer for question step #{step.id}"
  end

  def prep_none_of_the_above_answer_markdown(step)
    answer = step.question.none_of_the_above_answer

    return skipped_question_text if answer.blank?

    sanitize(answer)
  rescue StandardError
    raise FormattingError, "could not format none of the above answer for question step #{step.id}"
  end

  def sanitize(text)
    text
      .then { normalize_and_convert_whitespace_to_markdown _1 }
  end

  def skipped_question_text
    if @confirmation_email
      I18n.t("mailer.submission_confirmation.not_completed")
    else
      "[#{I18n.t('mailer.submission.question_skipped')}]"
    end
  end
end
