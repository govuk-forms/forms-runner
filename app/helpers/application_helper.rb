# frozen_string_literal: true

# ApplicationHelper
module ApplicationHelper
  def set_page_title(*args)
    content_for(:title) { join_title_elements(args) }
  end

  def form_title(page_name:, form_name:, mode:, error: false)
    mode_string = if mode.preview_draft?
                    " - #{t('mode.title_text_preview-draft')}"
                  elsif mode.preview_archived?
                    " - #{t('mode.title_text_preview-archived')}"
                  elsif mode.preview_live?
                    " - #{t('mode.title_text_preview-live')}"
                  else
                    ""
                  end
    "#{t('page_titles.error_prefix') if error}#{page_name}#{mode_string} - #{form_name}"
  end

  def site_name(form:)
    (form&.has_custom_branding? ? form.branding["organisation_name"] : "GOV.UK")
  end

  def theme_colour(form:)
    (form&.has_custom_branding? ? form.branding["background_colour"] : "#1d70b8")
  end

  def question_text_with_hidden_mode(question_text, mode)
    [CGI.escapeHTML(question_text), hidden_text_mode(mode)].compact_blank.join(" ").html_safe
  end

  def format_paragraphs(text)
    HtmlMarkdownSanitizer.new.format_paragraphs(text)
  end

  def govuk_assets_path
    "/node_modules/govuk-frontend/dist/govuk/assets"
  end

  def init_autocomplete_script
    content_for(:body_end) do
      javascript_tag defer: true do
        "
      document.addEventListener('DOMContentLoaded', function(event) {
        if(window.dfeAutocomplete !== undefined && typeof window.dfeAutocomplete === 'function') {
          dfeAutocomplete({
            showAllValues: true,
            rawAttribute: false,
            source: false,
            autoselect: false,
            tNoResults: () => '#{I18n.t('autocomplete.no_results')}',
            tStatusQueryTooShort: (minQueryLength) => `#{I18n.t('autocomplete.status.query_too_short')}`,
            tStatusNoResults: () => '#{I18n.t('autocomplete.status.no_results')}',
            tStatusSelectedOption: (selectedOption, length, index) => `#{I18n.t('autocomplete.status.selected_option')}`,
            tStatusResults: (length, contentSelectedOption) => (length === 1 ? `#{I18n.t('autocomplete.status.results_single')}` : `#{I18n.t('autocomplete.status.results_plural')}`),
            tAssistiveHint: () => '#{I18n.t('autocomplete.assistive_hint')}',
          })
        }
      });
        ".html_safe
      end
    end
  end

private

  def join_title_elements(title_elements)
    title_elements.compact.join(" – ")
  end

  def hidden_text_mode(mode)
    return "" unless mode.preview?

    mode_name = if mode.preview_draft?
                  "draft"
                elsif mode.preview_archived?
                  "archived"
                elsif mode.preview_live?
                  "live"
                end
    "<span class='govuk-visually-hidden'>&nbsp;#{t("page.#{mode_name}_preview")}</span>".html_safe
  end
end
