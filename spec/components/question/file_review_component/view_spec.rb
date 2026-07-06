require "rails_helper"

RSpec.describe Question::FileReviewComponent::View, type: :component do
  let(:form_document_step) { build :v2_question_step, answer_type: "file" }
  let(:is_optional) { false }
  let(:question_text) { "Upload a file" }
  let(:page_heading) { nil }
  let(:hint_text) { nil }
  let(:question) { build :file, :with_uploaded_file, question_text:, is_optional:, page_heading:, hint_text: }
  let(:mode) { Mode.new("form") }
  let(:remove_file_confirmation_url) { "/remove_file_confirmation" }

  before do
    render_inline(described_class.new(question:, mode:, remove_file_confirmation_url:))
  end

  it "renders the question text as a h1" do
    expect(page.find("h1")).to have_text(question.question_text_with_optional_suffix)
  end

  context "when the question has hint text" do
    let(:hint_text) { Faker::Lorem.sentence }

    it "outputs the hint text" do
      expect(page.find(".govuk-hint")).to have_text(hint_text)
    end
  end

  context "when the question has no hint text" do
    it "does not output the hint text" do
      expect(page).not_to have_css(".govuk-hint")
    end
  end

  it "renders the original file name" do
    expect(page).to have_content(question.original_filename)
  end

  it "has a link to the file removal confirmation page" do
    expect(page).to have_link(I18n.t("forms.review_file.show.remove"), href: remove_file_confirmation_url)
  end

  it "the link to the file removal confirmation page has hidden text" do
    expect(page).to have_css(".govuk-visually-hidden", text: I18n.t("forms.review_file.show.your_file"))
  end

  context "when the mode is preview" do
    let(:mode) { Mode.new("preview-draft") }

    it "renders the question text and extra suffix as a heading" do
      expect(page.find("h1").native.inner_html).to eq("#{question.question_text} <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>")
    end
  end

  context "with unsafe question text" do
    let(:question_text) { "What is your name? <script>alert(\"Hi\")</script>" }
    let(:mode) { Mode.new("preview-draft") }

    it "returns the escaped title with the optional suffix" do
      expected_output = "What is your name? &lt;script&gt;alert(\"Hi\")&lt;/script&gt; <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>"
      expect(page.find("h1").native.inner_html).to eq(expected_output)
    end
  end

  it "has text to explain the file can be removed" do
    expect(page).to have_content(I18n.t("forms.review_file.show.remove_file_guidance"))
  end
end
