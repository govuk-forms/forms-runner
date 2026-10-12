require "rails_helper"

describe "forms/check_your_answers/show.html.erb" do
  let(:form) { build :form, :with_support }
  let(:support_details) { OpenStruct.new(email: form.support_email) }
  let(:question) { build :full_name_question }
  let(:step) { build :step, question: question }
  let(:context) { OpenStruct.new(form:) }

  before do
    assign(:current_context, context)
    assign(:form, form)
    assign(:mode, OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false))
    assign(:step, step)
    assign(:save_url, "/save")
    assign(:support_details, support_details)

    without_partial_double_verification do
      allow(view).to receive(:save_progress_path).and_return("/save-your-progress")
    end

    render template: "forms/step/show"
  end

  it "displays the help link" do
    expect(rendered).to have_text(I18n.t("support_details.get_help_with_this_form"))
  end

  it "does not display the file upload help text" do
    expect(rendered).not_to have_text(I18n.t("question/file.file_requirements.summary"))
  end

  it "does not display the save and exit link" do
    expect(rendered).not_to have_link(I18n.t("save_progress.save_and_exit"))
  end

  context "when save and return is enabled on the form" do
    let(:form) { build :form, :with_support, save_and_return: "enabled" }

    it "displays the save and exit link" do
      expect(rendered).to have_link(I18n.t("save_progress.save_and_exit"), href: "/save-your-progress")
    end
  end

  context "when the question asks for a file" do
    let(:question) { build :file }

    it "displays the file upload help text" do
      expect(rendered).to have_text(I18n.t("question/file.file_requirements.summary"))
      expect(rendered).to include(I18n.t("question/file.file_requirements.body_html"))
    end
  end
end
