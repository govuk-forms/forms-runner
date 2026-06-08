module Question
  module SelectionComponent
    class View < Question::Base
      attr_accessor :selection_html

      def before_render
        @selection_html = allow_multiple_answers? ? build_multiple_answers_from_a_list : build_single_answer_list_from_a_list
      end

    private

      def allow_multiple_answers?
        question.answer_settings.only_one_option != "true"
      end

      def build_single_answer_list_from_a_list
        form_builder.govuk_radio_buttons_fieldset(:selection, legend: { text: question_text_with_extra_suffix, **question_text_size_and_tag }, hint: { text: question.hint_text }) do
          safe_join([hidden_field, radio_button_options, none_of_the_above_radio_button].compact_blank)
        end
      end

      def build_multiple_answers_from_a_list
        form_builder.govuk_check_boxes_fieldset(:selection, legend: { text: question_text_with_extra_suffix, **question_text_size_and_tag }, hint: { text: question.hint_text }) do
          safe_join([checkbox_options, none_of_the_above_checkbox].compact_blank)
        end
      end

      def hidden_field
        form_builder.hidden_field :selection
      end

      def divider
        form_builder.govuk_radio_divider I18n.t("question/selection.divider")
      end

      def none_of_the_above_radio_button
        return nil unless question.is_optional?

        option = form_builder.govuk_radio_button :selection,
                                                 Question::Selection::NONE_OF_THE_ABOVE_VALUE,
                                                 label: { text: I18n.t("page.none_of_the_above") },
                                                 &method(:none_of_the_above_question_field)
        safe_join([divider, option])
      end

      def none_of_the_above_checkbox
        return nil unless question.is_optional?

        option = form_builder.govuk_check_box :selection,
                                              Question::Selection::NONE_OF_THE_ABOVE_VALUE,
                                              exclusive: true,
                                              label: { text: I18n.t("page.none_of_the_above") },
                                              &method(:none_of_the_above_question_field)
        safe_join([divider, option])
      end

      def none_of_the_above_question_field
        if question.has_none_of_the_above_question?
          form_builder.govuk_text_field :none_of_the_above_answer, label: { text: question.none_of_the_above_question_text }, width: "three-quarters"
        end
      end

      def radio_button_options
        question.answer_settings.selection_options.map.with_index do |option, index|
          form_builder.govuk_radio_button :selection, option.value, label: { text: option.name }, link_errors: index.zero?
        end
      end

      def checkbox_options
        question.answer_settings.selection_options.map.with_index do |option, index|
          form_builder.govuk_check_box :selection, option.value, label: { text: option.name }, link_errors: index.zero?
        end
      end
    end
  end
end
