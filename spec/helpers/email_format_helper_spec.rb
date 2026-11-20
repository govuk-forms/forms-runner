require "rails_helper"

RSpec.describe EmailFormatHelper, type: :helper do
  describe "#normalize_whitespace" do
    it "strips leading/trailing whitespace and collapses multiple blank lines to two newlines" do
      input_text = "  Line1\r\n\r\n\r\nLine2\n\n  Line3  "
      expect(helper.normalize_whitespace(input_text)).to eq("Line1\n\nLine2\n\nLine3")
    end
  end
end
