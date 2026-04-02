require "rails_helper"

RSpec.describe Question::FileRemoveComponent::View, type: :component do
  let(:form_document_step) { build :form_document_step, answer_type: "file" }
  let(:is_optional) { false }
  let(:question_text) { "Upload a file" }
  let(:page_heading) { nil }
  let(:hint_text) { nil }
  let(:question) { build :file, :with_uploaded_file, question_text:, is_optional:, page_heading:, hint_text: }
  let(:mode) { Mode.new("form") }
  let(:remove_file_url) { "/remove_file" }

  before do
    render_inline(described_class.new(question:, mode:, remove_file_url:, remove_input: RemoveInput.new))
  end

  it "renders the correct h1" do
    expect(page.find("h1")).to have_text(I18n.t("forms.remove_file.show.title"))
  end

  it "renders the original file name" do
    expect(page).to have_content(question.original_filename)
  end

  it "renders radio buttons to confirm removal" do
    expect(page).to have_css("form[action='#{remove_file_url}'][method='post']")
    expect(page).to have_css("fieldset", text: I18n.t("forms.remove_file.show.radios_legend"))
    expect(page).to have_field("Yes", type: :radio)
    expect(page).to have_field("No", type: :radio)
  end

  it "has a button continue with file removal" do
    within(page.find("form[action='#{remove_file_url}'][method='post']")) do
      expect(page).to have_button("Continue")
    end
  end
end
