module CopyOfAnswersCheckComponent
  class View < ApplicationComponent
    def initialize(form:, steps:, confirmation_details_store:)
      @form = form
      @steps = steps
      @confirmation_details_store = confirmation_details_store
      @wants_copy_of_answers = confirmation_details_store.wants_copy_of_answers?
      super()
    end

    def rows
      unless @wants_copy_of_answers
        [{
          key: { text: helpers.sanitize(I18n.t("form.check_your_answers.does_not_want_copy_of_answers_key")) },
          value: { text: helpers.sanitize(I18n.t("form.check_your_answers.does_not_want_copy_of_answers_value")) },
          actions: [{ text: I18n.t("govuk_components.govuk_summary_list.change"), href: "copy-of-answers", visually_hidden_text: I18n.t("govuk_components.govuk_summary_list.change") }],
        }]
      end
    end

    def confirmation_email_address
      if @confirmation_details_store.try(:get_copy_of_answers_email_address).present?
        @confirmation_details_store.get_copy_of_answers_email_address
      end
    end

    def title?
      !@confirmation_details_store.wants_copy_of_answers?
    end

    def full_width?
      # this is to keep this section the same width as the check your answers component
      @steps.any? { |step| step.question.has_long_answer? }
    end
  end
end
