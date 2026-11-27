require "rails_helper"

describe "forms/continue_saved_form/not_found.html.erb" do
  let(:form) { build :form, save_and_return: "enabled", start_page: 1 }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:resume_options_path) { "/form/#{form.id}/#{form.form_slug}/what-do-you-want-to-do" }
  let(:submit_path) { "/form/#{form.id}/#{form.form_slug}/continue-saved-form/not-found" }
  let(:start_new_form_input) { StartNewFormInput.new }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:start_new_form_input, start_new_form_input)
    assign(:email, "test@example.com")

    allow(view).to receive_messages(resume_options_path:, submit_continue_saved_form_not_found_path: submit_path)

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.continue_saved_form.not_found.title')} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: I18n.t("forms.continue_saved_form.not_found.title"))
  end

  it "has a back link to the page asking whether to start a new form or continue a saved one" do
    expect(view.content_for(:back_link)).to have_link(I18n.t("forms.back"), href: resume_options_path)
  end

  it "shows the email address the user is signed into GOV.UK One Login with" do
    expect(rendered).to have_css("p", text: "You're signed into GOV.UK One Login with the email address test@example.com.")
    expect(rendered).to have_css("strong", text: "test@example.com")
  end

  it "has a form that posts to the not found submit path" do
    expect(rendered).to have_css("form[action='#{submit_path}'][method='post']")
  end

  it "asks whether the user wants to start a new form" do
    expect(rendered).to have_css("legend", text: I18n.t("helpers.legend.start_new_form_input.start_new_form"))
  end

  it "has radio buttons to start a new form or sign in with a different One Login" do
    expect(rendered).to have_field(I18n.t("helpers.label.start_new_form_input.start_new_form_options.yes"), type: :radio, with: "yes")
    expect(rendered).to have_field(I18n.t("helpers.label.start_new_form_input.start_new_form_options.no"), type: :radio, with: "no")
  end

  it "has a continue button" do
    expect(rendered).to have_button(I18n.t("continue"))
  end

  it "does not show an error summary" do
    expect(rendered).not_to have_css(".govuk-error-summary")
  end

  context "when the input has errors" do
    let(:start_new_form_input) { StartNewFormInput.new.tap(&:validate) }

    it "shows the error summary" do
      expect(rendered).to have_css(".govuk-error-summary", text: I18n.t("activemodel.errors.models.start_new_form_input.attributes.start_new_form.blank"))
    end

    it "prefixes the page title with Error" do
      expect(view.content_for(:title)).to start_with(I18n.t("page_titles.error_prefix"))
    end
  end
end
