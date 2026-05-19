require "rails_helper"

RSpec.describe EmailFormatHelper, type: :helper do
  describe "#normalize_whitespace" do
    it "strips leading/trailing whitespace and collapses multiple blank lines to two newlines" do
      input_text = "  Line1\r\n\r\n\r\nLine2\n\n  Line3  "
      expect(helper.normalize_whitespace(input_text)).to eq("Line1\n\nLine2\n\nLine3")
    end
  end

  describe "#convert_newlines_to_html" do
    it "replaces newlines with <br/>" do
      input_text = "a\nb\n"
      expect(helper.convert_newlines_to_html(input_text)).to eq("a<br/>b<br/>")
    end
  end

  describe "#normalize_whitespace_and_convert_to_html" do
    it "normalizes whitespace then converts newlines to <br/>" do
      input_text = "  Line1\n\n\nLine2  "
      expect(helper.normalize_whitespace_and_convert_to_html(input_text)).to eq("Line1<br/><br/>Line2")
    end
  end

  describe "#format_date" do
    it "formats a datetime using the expected date format" do
      date_time = Time.zone.local(2020, 12, 5, 10, 30, 0)
      expected_output = "5 December 2020"
      expect(helper.format_date(date_time)).to eq(expected_output)
    end

    it "formats the datetime using the I18n locale" do
      date_time = Time.zone.local(2020, 12, 5, 10, 30, 0)
      I18n.with_locale(:cy) do
        expected_output = "5 Rhagfyr 2020"
        expect(helper.format_date(date_time)).to eq(expected_output)
      end
    end
  end

  describe "#format_time" do
    it "formats a datetime to hour:minuteam/pm without leading zero" do
      date_time = Time.zone.local(2020, 12, 5, 4, 5, 0)
      expected_output = "4:05am"
      expect(helper.format_time(date_time)).to eq(expected_output)
    end
  end

  describe "#markdown_to_html" do
    it "renders markdown to sanitized html" do
      input = "# Heading\n\nThis is *italic* and **bold**"
      output = helper.markdown_to_html(input)
      expected = "<p>Heading</p>\n<p>This is italic and bold</p>"
      expect(output).to eq(expected)
    end

    it "strips disallowed HTML tags from the rendered markdown" do
      input = "This is safe\n\n<script>alert('x')</script>\n\n**bold**"
      output = helper.markdown_to_html(input)
      expected = "<p>This is safe</p>\n<p>&lt;script&gt;alert('x')&lt;/script&gt;</p>\n<p>bold</p>"
      expect(output).to eq(expected)
    end
  end

  describe "#markdown_to_plain_text" do
    it "renders markdown to plain text" do
      input = "# Heading\n\nThis is *italic* and **bold**\n\n- List item\n- Other item\n[Link text](https://www.link.com)"
      plain = helper.markdown_to_plain_text(input)
      expected = "Heading\n\nThis is italic and bold\n• List item\n• Other item\nLink text: https://www.link.com"
      expect(plain).to eq(expected)
    end
  end
end
