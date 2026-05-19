require "govuk_forms_markdown"

module EmailFormatHelper
  def normalize_whitespace(text)
    text.strip.gsub(/\r\n?/, "\n").split(/\n\n+/).map(&:strip).join("\n\n")
  end

  def convert_newlines_to_html(text)
    text.gsub("\n", "<br/>")
  end

  def normalize_whitespace_and_convert_to_html(text)
    output = normalize_whitespace(text)
    convert_newlines_to_html(output)
  end

  def markdown_to_html(markdown)
    HtmlMarkdownSanitizer.new.render_scrubbed_markdown(markdown, allow_headings: false, for_email: true)
  end

  def markdown_to_plain_text(markdown)
    GovukFormsMarkdown.render_plain_text(markdown)
  end

  def format_date(datetime)
    I18n.l(datetime, format: "%-d %B %Y")
  end

  def format_time(datetime)
    datetime.strftime("%l:%M%P").strip
  end
end
