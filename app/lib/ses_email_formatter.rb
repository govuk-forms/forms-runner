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

  def build_question_answers_section_html(heading_tag: "h3")
    @steps.map { |step|
      [prep_question_title_html(step, heading_tag),
       prep_answer_text_html(step)].join
    }.join(H_RULE)
  end

  def build_question_answers_section_plain_text
    @steps.map { |step|
      [prep_question_title_plain_text(step),
       prep_answer_text_plain_text(step)].join("\n\n")
    }.join(H_RULE_PLAIN_TEXT)
  end

private

  def prep_question_title_html(step, heading_tag)
    "<#{heading_tag}>#{prep_question_title_plain_text(step)}</#{heading_tag}>"
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

  def prep_html_none_of_the_above_answer_text(step)
    [
      "<p>#{convert_newlines_to_html(prep_answer_text(step))}</p>",
      "<h4>#{convert_newlines_to_html(prep_none_of_the_above_question_text(step))}</h4>",
      "<p>#{convert_newlines_to_html(prep_none_of_the_above_answer_text(step))}</p>",
    ]
  end

  def prep_question_title_plain_text(step)
    step.question.question_text
  end

  def prep_none_of_the_above_question_text(step)
    step.question.none_of_the_above_question_text
  end

  def prep_answer_text(step)
    answer = step.show_answer_in_email(submission_reference: @submission_reference, confirmation_email: @confirmation_email)

    return "[#{I18n.t('mailer.submission.question_skipped')}]" if answer.blank?

    sanitize(answer)
  rescue StandardError
    raise FormattingError, "could not format answer for question step #{step.id}"
  end

  def prep_none_of_the_above_answer_text(step)
    answer = step.question.none_of_the_above_answer

    return "[#{I18n.t('mailer.submission.question_skipped')}]" if answer.blank?

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
end
