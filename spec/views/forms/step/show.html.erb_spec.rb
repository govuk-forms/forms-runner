require "rails_helper"

describe "forms/check_your_answers/show.html.erb" do
  let(:form_document) { build :v2_form_document, :with_support }
  let(:form) { Form.new(form_document) }
  let(:support_details) { OpenStruct.new(email: form.support_email) }
  let(:question) { build :full_name_question }
  let(:step) { build :step, question: question }
  let(:context) { OpenStruct.new(form:) }

  before do
    assign(:current_context, context)
    assign(:mode, OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false))
    assign(:step, step)
    assign(:save_url, "/save")
    assign(:support_details, support_details)

    render template: "forms/step/show"
  end

  it "displays the help link" do
    expect(rendered).to have_text(I18n.t("support_details.get_help_with_this_form"))
  end

  it "does not display the file upload help text" do
    expect(rendered).not_to have_text(I18n.t("question/file.file_requirements.summary"))
  end

  context "when the question asks for a file" do
    let(:question) { build :file }

    it "displays the file upload help text" do
      expect(rendered).to have_text(I18n.t("question/file.file_requirements.summary"))
      expect(rendered).to include(I18n.t("question/file.file_requirements.body_html"))
    end
  end
end
