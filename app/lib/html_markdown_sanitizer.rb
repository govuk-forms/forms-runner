require "govuk_forms_markdown"

class HtmlMarkdownSanitizer
  include ERB::Util
  include ActionView::Helpers::TextHelper

  # Escapes all HTML characters and converts line breaks into break/paragraph elements.
  # Use this to render multiline text entered by members of the public.
  def format_paragraphs(text)
    simple_format(html_escape(text))
  end

  # renders a HTML string with only the tags allowed by a given Scrubber object.
  def sanitize_html(html, scrubber)
    ActionController::Base.helpers.sanitize(html, scrubber:)
  end

  # renders Markdown to HTML and strips out all tags not explicitly allowed in LimitedHtmlScrubber.
  # Use this instead of rendering Markdown directly in views.
  def render_scrubbed_markdown(markdown, allow_headings: true, for_email: false)
    html = if for_email
             GovukFormsMarkdown.render_for_email(markdown)
           else
             GovukFormsMarkdown.render(markdown, locale: I18n.locale.to_s)
           end

    sanitize_html(html, LimitedHtmlScrubber.new(allow_headings:, for_email:))
  end

  # renders the limited subset of HTML allowed by LimitedHtmlScrubber and strips all other tags.
  def render_scrubbed_html(unprocessed_html)
    scrubber = LimitedHtmlScrubber.new(allow_headings: false)

    simple_format(unprocessed_html, {}, sanitize: true, sanitize_options: { scrubber: })
  end
end
