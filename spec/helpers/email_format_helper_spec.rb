require "rails_helper"

RSpec.describe EmailFormatHelper, type: :helper do
  describe "#normalize_whitespace" do
    it "strips leading/trailing whitespace and collapses multiple blank lines to two newlines" do
      input_text = "  Line1\r\n\r\n\r\nLine2\n\n  Line3  "
      expect(helper.normalize_whitespace(input_text)).to eq("Line1\n\nLine2\n\nLine3")
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
end
