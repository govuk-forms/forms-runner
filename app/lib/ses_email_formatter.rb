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

  def build_question_answers_section_html(heading_level: 3)
    @steps.map { |step|
      [prep_question_title_html(step, heading_level),
       prep_answer_text_html(step)].join
    }.join(H_RULE)
  end

  def build_question_answers_section_plain_text
    @steps.map { |step|
      [prep_question_title_plain_text(step),
       prep_answer_text_plain_text(step)].join("\n\n")
    }.join(H_RULE_PLAIN_TEXT)
  end

  def build_question_answers_section_markdown(heading_level: 3)
    @steps.map { |step|
      [prep_question_title_markdown(step, heading_level),
       prep_answer_text_markdown(step)].join("\n\n")
    }.join(H_RULE_PLAIN_TEXT)
  end

private

  def prep_question_title_html(step, heading_level)
    case heading_level
    when 3
      "<h3 style=\"font-size: 21px; line-height: 25px; font-weight: bold; color: #0B0C0C;\">#{prep_question_title_plain_text(step)}</h3>"
    when 4
      "<h4 style=\"font-size: 19px; line-height: 25px; font-weight: bold; color: #0B0C0C;\">#{prep_question_title_plain_text(step)}</h4>"
    else
      raise FormattingError, "unsupported heading level: #{heading_level}"
    end
  end

  def prep_question_title_markdown(step, heading_level)
    case heading_level
    when 3
      "### #{prep_question_title_plain_text(step)}"
    when 4
      "#### #{prep_question_title_plain_text(step)}"
    else
      raise FormattingError, "unsupported heading level: #{heading_level}"
    end
  end

  def prep_answer_text_html(step)
    if step.is_selection_with_none_of_the_above_answer?
      prep_html_none_of_the_above_answer_text(step)
    else
      "<p>#{convert_newlines_to_html(prep_answer_text(step))}</p>"
    end
  rescue StandardError
    raise FormattingError, "could not format answer for question step #{step.id}"
  end

  def prep_answer_text_markdown(step)
    if step.is_selection_with_none_of_the_above_answer?
      prep_markdown_none_of_the_above_answer_text(step)
    else
      prep_answer_text(step)
    end
  rescue StandardError
    raise FormattingError, "could not format answer for question step #{step.id}"
  end

  def prep_html_none_of_the_above_answer_text(step)
    [
      "<p>#{convert_newlines_to_html(prep_answer_text(step))}</p>",
      "<h4>#{convert_newlines_to_html(prep_none_of_the_above_question_text(step))}</h4>",
      "<p>#{convert_newlines_to_html(prep_none_of_the_above_answer_text(step))}</p>",
    ]
  end

  def prep_markdown_none_of_the_above_answer_text(step)
    [
      prep_answer_text(step),
      "#### #{prep_none_of_the_above_question_text(step)}",
      prep_none_of_the_above_answer_text(step),
    ].join("\n\n")
  end

  def prep_question_title_plain_text(step)
    step.question.question_text
  end

  def prep_none_of_the_above_question_text(step)
    step.question.none_of_the_above_question_text
  end

  def prep_answer_text(step)
    answer = step.show_answer_in_email(submission_reference: @submission_reference, confirmation_email: @confirmation_email)

    return skipped_question_text if answer.blank?

    sanitize(answer)
  rescue StandardError
    raise FormattingError, "could not format answer for question step #{step.id}"
  end

  def prep_none_of_the_above_answer_text(step)
    answer = step.question.none_of_the_above_answer

    return skipped_question_text if answer.blank?

    sanitize(answer)
  rescue StandardError
    raise FormattingError, "could not format none of the above answer for question step #{step.id}"
  end

  def prep_answer_text_plain_text(step)
    if step.is_selection_with_none_of_the_above_answer?
      prep_plain_text_none_of_the_above_answer_text(step)
    else
      prep_answer_text(step)
    end
  end

  def prep_plain_text_none_of_the_above_answer_text(step)
    [
      prep_answer_text(step),
      prep_none_of_the_above_question_text(step),
      prep_none_of_the_above_answer_text(step),
    ].join("\n\n")
  end

  def sanitize(text)
    text
      .then { normalize_whitespace _1 }
  end

  def skipped_question_text
    if @confirmation_email
      I18n.t("mailer.submission_confirmation.not_completed")
    else
      "[#{I18n.t('mailer.submission.question_skipped')}]"
    end
  end
end
