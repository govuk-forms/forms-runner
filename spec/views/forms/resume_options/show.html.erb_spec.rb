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
      allow(view).to receive(:resume_options_continue_path).and_return("/resume_options_continue")
    end

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.resume_options.show.title')} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: I18n.t("forms.resume_options.show.title"))
  end

  it "displays the start a new form and continue filling in a saved form options" do
    expect(rendered).to have_field(I18n.t("helpers.label.resume_options_input.options.start_new"), type: :radio)
    expect(rendered).to have_field(I18n.t("helpers.label.resume_options_input.options.continue_saved"), type: :radio)
  end

  it "has a hint on the continue filling in a saved form option" do
    continue_option = Capybara.string(rendered).find(".govuk-radios__item", text: I18n.t("helpers.label.resume_options_input.options.continue_saved"))

    expect(continue_option).to have_css(".govuk-radios__hint", text: I18n.t("helpers.hint.resume_options_input.options.continue_saved"))
  end

  it "has a continue button" do
    expect(rendered).to have_button(I18n.t("continue"))
  end
end
