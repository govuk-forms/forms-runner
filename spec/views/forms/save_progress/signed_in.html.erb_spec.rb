require "rails_helper"

describe "forms/save_progress/signed_in.html.erb" do
  let(:form) { build :form, save_and_return: "enabled" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:one_login_email) { "user@example.com" }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:one_login_email, one_login_email)
    assign(:back_link, "/previous-step")
    assign(:continue_with_one_login_input, ContinueWithOneLoginInput.new)

    without_partial_double_verification do
      allow(view).to receive(:create_save_progress_path).with(form.id, form.form_slug).and_return("/save-your-progress")
    end

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.save_progress.signed_in.title')} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: I18n.t("forms.save_progress.signed_in.title"))
  end

  it "has a back link to the step the user came from" do
    expect(view.content_for(:back_link)).to have_link(I18n.t("forms.back"), href: "/previous-step")
  end

  it "has the body text including the user's email address" do
    expect(rendered).to include(I18n.t("forms.save_progress.signed_in.body_html", email: one_login_email))
  end

  it "asks whether the user wants to continue with this GOV.UK One Login" do
    expect(rendered).to have_css("legend", text: I18n.t("helpers.legend.continue_with_one_login_input.continue_with_this_one_login"))
    expect(rendered).to have_field(I18n.t("helpers.label.continue_with_one_login_input.continue_with_this_one_login_options.yes"), type: :radio)
    expect(rendered).to have_field(I18n.t("helpers.label.continue_with_one_login_input.continue_with_this_one_login_options.no"), type: :radio)
  end

  it "has hint text for the option to use a different GOV.UK One Login" do
    expect(rendered).to have_css(".govuk-radios__hint", text: I18n.t("helpers.hint.continue_with_one_login_input.continue_with_this_one_login_options.no"))
  end

  it "has a continue button that posts to save the user's progress" do
    expect(rendered).to have_css("form[action='/save-your-progress'][method='post']")
    expect(rendered).to have_button(I18n.t("continue"))
  end

  it "does not have a button that posts to GOV.UK One Login" do
    expect(rendered).not_to have_css("form[action='/auth/govuk_one_login']")
  end
end
