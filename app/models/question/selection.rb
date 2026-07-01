module Question
  class Selection < QuestionBase
    attribute :selection
    attribute :none_of_the_above_answer

    before_validation :clear_none_of_the_above_answer_if_not_selected

    validates :selection, presence: true
    validate :selection, :validate_checkbox, if: :allow_multiple_answers?
    validate :selection, :validate_radio, unless: :allow_multiple_answers?
    validates :none_of_the_above_answer, length: { maximum: 499 }

    # In the case of a selection component that uses an autocomplete UI component, we show the input for the none
    # of the above question on a separate page, so we provide a context to skip the validation of
    # none_of_the_above_answer for the first page.
    validates :none_of_the_above_answer,
              presence: true,
              if: :validate_none_of_the_above_answer_presence?,
              unless: -> { validation_context == :skip_none_of_the_above_question_validation }

    NONE_OF_THE_ABOVE_VALUE = "none_of_the_above".freeze

    def allow_multiple_answers?
      answer_settings.only_one_option != "true"
    end

    def with_none_of_the_above_selected
      self.selection = allow_multiple_answers? ? [NONE_OF_THE_ABOVE_VALUE] : NONE_OF_THE_ABOVE_VALUE
    end

    def answered?
      return false if show_none_of_the_above_question? && none_of_the_above_answer.nil?

      super()
    end

    def show_answer
      return selection_names.join(", ") if allow_multiple_answers?

      selection_name
    end

    def show_answer_in_email(*)
      return selection_names.join("\n\n") if allow_multiple_answers?

      selection_name
    end

    def show_answer_in_csv(*)
      if show_none_of_the_above_question?
        Hash[question_text, show_answer_with_none_of_the_above]
      else
        Hash[question_text, show_answer]
      end
    end

    def show_answer_in_json(*)
      hash = {}

      if allow_multiple_answers?
        hash[:selections] = selection_names
      elsif has_none_of_the_above_question?
        hash[:selection] = selection_name
      end

      if show_none_of_the_above_question?
        hash[:none_of_the_above_answer] = none_of_the_above_answer
        hash[:answer_text] = show_answer_with_none_of_the_above
      else
        hash[:answer_text] = show_answer
      end

      hash
    end

    def show_optional_suffix
      false
    end

    def selection_options_with_none_of_the_above
      options = answer_settings.selection_options

      return options unless is_optional?

      [*options, none_of_the_above_option]
    end

    def autocomplete_component?
      answer_settings.selection_options.count > 30
    end

    def show_none_of_the_above_question?
      has_none_of_the_above_question? && none_of_the_above_selected?
    end

    def has_none_of_the_above_question?
      none_of_the_above_question.present?
    end

    def none_of_the_above_question_text
      return nil unless has_none_of_the_above_question?
      return none_of_the_above_question.question_text if none_of_the_above_question.is_optional != "true"

      "#{none_of_the_above_question.question_text} #{I18n.t('page.optional')}"
    end

  private

    def clear_none_of_the_above_answer_if_not_selected
      self.none_of_the_above_answer = nil unless none_of_the_above_selected?
    end

    def allowed_options
      selection_options_with_none_of_the_above.map(&:value)
    end

    def none_of_the_above_option
      OpenStruct.new(name: I18n.t("page.none_of_the_above"), value: NONE_OF_THE_ABOVE_VALUE)
    end

    def selection_without_blanks
      return [] if selection.nil?

      selection.reject(&:blank?)
    end

    def selection_name
      return nil if selection.nil?
      return "" if selection.blank?

      name_from_value(selection)
    end

    def selection_names
      selection_without_blanks.map { |selected| name_from_value(selected) }
    end

    # Show the selection option name, which can be different to the value. Value
    # should stay the same across FormDocuments in different languages.
    def name_from_value(selected)
      @options_by_value ||= selection_options_with_none_of_the_above.index_by(&:value)
      @options_by_value[selected]&.name
    end

    def validate_radio
      errors.add(:selection, :inclusion) if allowed_options.exclude?(selection)
    end

    def validate_checkbox
      return errors.add(:selection, is_optional? ? :both_none_and_value_selected : :checkbox_blank) if selection_without_blanks.empty?
      return errors.add(:selection, :both_none_and_value_selected) if selection_without_blanks.count > 1 && NONE_OF_THE_ABOVE_VALUE.in?(selection_without_blanks)

      errors.add(:selection, :inclusion) if selection_without_blanks.any? { |item| allowed_options.exclude?(item) }
    end

    def validate_none_of_the_above_answer_presence?
      none_of_the_above_question.present? && none_of_the_above_question.is_optional != "true" && none_of_the_above_selected?
    end

    def none_of_the_above_question
      return nil unless is_optional?
      return nil unless answer_settings.respond_to?(:none_of_the_above_question)
      return nil unless answer_settings.none_of_the_above_question.respond_to?(:question_text)

      answer_settings.none_of_the_above_question
    end

    def none_of_the_above_selected?
      return selection_without_blanks.include?(NONE_OF_THE_ABOVE_VALUE) if allow_multiple_answers?

      selection == NONE_OF_THE_ABOVE_VALUE
    end

    def show_answer_with_none_of_the_above
      "#{I18n.t('page.none_of_the_above')} - #{none_of_the_above_answer}"
    end
  end
end
