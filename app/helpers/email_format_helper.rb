require "govuk_forms_markdown"

module EmailFormatHelper
  def normalize_whitespace(text)
    text.strip.gsub(/\r\n?/, "\n").split(/\n\n+/).map(&:strip).join("\n\n")
  end

  def convert_single_newlines_to_markdown_linebreaks(text)
    text.gsub(/(?<!\n)\n(?!\n)/, "  \n")
  end

  def normalize_and_convert_whitespace_to_markdown(text)
    output = normalize_whitespace(text)
    convert_single_newlines_to_markdown_linebreaks(output)
  end
end
