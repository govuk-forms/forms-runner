module PreviewComponent
  class MissingQuestionEditLink < StandardError; end

  class View < ApplicationComponent
    def initialize(mode:, question_edit_link: nil)
      @mode = mode || Mode.new
      @question_edit_link = question_edit_link

      super()
    end

    def render?
      @mode.preview?
    end

  private

    def phase_banner_colour
      if @mode.preview_draft?
        "yellow"
      elsif @mode.preview_archived?
        "orange"
      else
        "teal"
      end
    end

    def phase_banner_text
      if @mode.preview_draft? && @question_edit_link.present?
        "#{t("mode.phase_banner_text_#{@mode}")}. #{govuk_link_to(t('mode.phase_banner_text_preview-draft_edit_link'), @question_edit_link)}".html_safe
      else
        t("mode.phase_banner_text_#{@mode}")
      end
    end
  end
end
