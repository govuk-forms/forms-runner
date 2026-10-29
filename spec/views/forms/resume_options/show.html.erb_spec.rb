require "rails_helper"

describe "forms/resume_options/show.html.erb" do
  let(:form) { build :form }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:resume_options_input) { ResumeOptionsInput.new }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:resume_options_input, resume_options_input)

    without_partial_double_verification do
      allow(view).to receive(:save_resume_options_path).and_return("/save_resume_options")
    end

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.resume_options.show.title')} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: I18n.t("forms.resume_options.show.title"))
  end
end
