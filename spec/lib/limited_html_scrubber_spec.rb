require "rails_helper"

RSpec.describe LimitedHtmlScrubber do
  let(:limited_html_scrubber) { described_class.new }

  it "returns an array of html tags allowed" do
    expect(limited_html_scrubber.tags).to eq %w[a ol ul li p br]
  end

  it "returns an array of html attributes allowed" do
    expect(limited_html_scrubber.attributes).to eq %w[href class rel target title]
  end

  context "when used with sanitize" do
    context "when the string contains only allowed markup" do
      let(:input) { "<a href=\"#\" target=\"_blank\" rel=\"noreferrer noopener\">A perfectly innocent link</a>" }

      it "returns the allowed markup unchanged" do
        sanitized_string = ActionController::Base.helpers.sanitize(input, scrubber: limited_html_scrubber)
        expect(sanitized_string).to eq "<a href=\"#\" target=\"_blank\" rel=\"noreferrer noopener\">A perfectly innocent link</a>"
      end
    end

    context "when the string contains an allowed tag with a disallowed attribute" do
      let(:input) { "<a href=\"#\" class=\"govuk-link\" target=\"blank\" rel=\"noopener noreferrer\" style=\"color: rebeccapurple\" onClick=\"alert('some malicious js!')\">A link with some dodgy styling and JS attached</a>" }

      it "returns the tag with the disallowed attributes removed" do
        sanitized_string = ActionController::Base.helpers.sanitize(input, scrubber: limited_html_scrubber)
        expect(sanitized_string).to eq "<a href=\"#\" class=\"govuk-link\" target=\"blank\" rel=\"noopener noreferrer\">A link with some dodgy styling and JS attached</a>"
      end
    end

    context "when the string contains disallowed markup" do
      let(:input) { "<a href=\"#\"><em>A</em> <strong class=\"bold\">perfectly</strong> <b style=\"font-weight: 700;\">innocent</b> <i>link</i></a><script>alert(\"malicious code!\")</script>" }

      it "sanitises the disallowed markup" do
        sanitized_string = ActionController::Base.helpers.sanitize(input, scrubber: limited_html_scrubber)
        expect(sanitized_string).to eq "<a href=\"#\">A perfectly innocent link</a>alert(\"malicious code!\")"
      end
    end
  end

  context "when headings are allowed" do
    let(:limited_html_scrubber) { described_class.new(allow_headings: true) }

    it "returns an array of html tags allowed" do
      expect(limited_html_scrubber.tags).to match_array %w[a h2 h3 ol ul li p br]
    end

    it "returns an array of html attributes allowed" do
      expect(limited_html_scrubber.attributes).to eq %w[href class rel target title]
    end

    context "when used with sanitize" do
      context "when the string contains only allowed markup" do
        let(:input) { "<h2>A heading</h2><a href=\"#\" target=\"_blank\" rel=\"noreferrer noopener\">A perfectly innocent link</a>" }

        it "returns the allowed markup unchanged" do
          sanitized_string = ActionController::Base.helpers.sanitize(input, scrubber: limited_html_scrubber)
          expect(sanitized_string).to eq "<h2>A heading</h2><a href=\"#\" target=\"_blank\" rel=\"noreferrer noopener\">A perfectly innocent link</a>"
        end
      end

      context "when the string contains an allowed tag with a disallowed attribute" do
        let(:input) { "<a href=\"#\" class=\"govuk-link\" target=\"blank\" rel=\"noopener noreferrer\" style=\"color: rebeccapurple\" onClick=\"alert('some malicious js!')\">A link with some dodgy styling and JS attached</a>" }

        it "returns the tag with the disallowed attributes removed" do
          sanitized_string = ActionController::Base.helpers.sanitize(input, scrubber: limited_html_scrubber)
          expect(sanitized_string).to eq "<a href=\"#\" class=\"govuk-link\" target=\"blank\" rel=\"noopener noreferrer\">A link with some dodgy styling and JS attached</a>"
        end
      end

      context "when the string contains disallowed markup" do
        let(:input) { "<h2>A heading</h2><a href=\"#\"><em>A</em> <strong class=\"bold\">perfectly</strong> <b style=\"font-weight: 700;\">innocent</b> <i>link</i></a><script>alert(\"malicious code!\")</script>" }

        it "sanitises the disallowed markup" do
          sanitized_string = ActionController::Base.helpers.sanitize(input, scrubber: limited_html_scrubber)
          expect(sanitized_string).to eq "<h2>A heading</h2><a href=\"#\">A perfectly innocent link</a>alert(\"malicious code!\")"
        end
      end
    end
  end

  context "when for_email is true" do
    let(:limited_html_scrubber) { described_class.new(for_email: true) }

    it "returns an array of html tags allowed including table tags" do
      expect(limited_html_scrubber.tags).to eq %w[a ol ul li p br table tr td]
    end

    it "returns an array of html attributes allowed including style" do
      expect(limited_html_scrubber.attributes).to eq %w[href class rel target title style]
    end

    context "when used with sanitize" do
      let(:input) { "<a href=\"#\" style=\"color:#0B0C0C;\">A perfectly innocent link</a><table><tr><td><ul><li>An item</li></ul></td></tr></table>" }

      it "returns the allowed markup unchanged" do
        sanitized_string = ActionController::Base.helpers.sanitize(input, scrubber: limited_html_scrubber)
        expect(sanitized_string).to eq "<a href=\"#\" style=\"color:#0B0C0C;\">A perfectly innocent link</a><table><tr><td><ul><li>An item</li></ul></td></tr></table>"
      end
    end
  end
end
