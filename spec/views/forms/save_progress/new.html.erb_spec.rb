require "rails_helper"

describe "forms/save_progress/new.html.erb" do
  let(:form) { build :form, save_and_return: "enabled" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:one_login_email) { nil }

  before do
    assign(:current_context, OpenStruct.new(form:, next_step_slug: "2"))
    assign(:form, form)
    assign(:mode, mode)
    assign(:one_login_email, one_login_email)

    without_partial_double_verification do
      allow(view).to receive(:form_step_path).with(form.id, form.form_slug, "2").and_return("/previous-step")
      allow(view).to receive(:save_progress_path).with(form.id, form.form_slug).and_return("/save-your-progress")
    end

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.save_progress.new.title')} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: I18n.t("forms.save_progress.new.title"))
  end

  it "has a back link to the step the user came from" do
    expect(view.content_for(:back_link)).to have_link(I18n.t("forms.back"), href: "/previous-step")
  end

  context "when the user is not signed in to GOV.UK One Login" do
    it "has the body text" do
      expect(rendered).to include(I18n.t("forms.save_progress.new.body_html"))
    end

    it "has a button that posts to GOV.UK One Login" do
      expect(rendered).to have_css("form[action='/auth/govuk_one_login'][method='post']")
      expect(rendered).to have_button(I18n.t("forms.save_progress.new.continue_to_one_login_button"))
    end

    it "does not have a link to sign in with a different GOV.UK One Login" do
      expect(rendered).not_to have_link(I18n.t("forms.save_progress.new.sign_in_different_link"))
    end
  end

  context "when the user is signed in to GOV.UK One Login" do
    let(:one_login_email) { "user@example.com" }

    it "has the body text including the user's email address" do
      expect(rendered).to include(I18n.t("forms.save_progress.new.signed_in_body_html", email: one_login_email))
    end

    it "has a continue button that posts to save the user's progress" do
      expect(rendered).to have_css("form[action='/save-your-progress'][method='post']")
      expect(rendered).to have_button(I18n.t("continue"))
    end

    it "does not have a button that posts to GOV.UK One Login" do
      expect(rendered).not_to have_css("form[action='/auth/govuk_one_login']")
    end

    it "has a link to sign in with a different GOV.UK One Login" do
      expect(rendered).to have_link(I18n.t("forms.save_progress.new.sign_in_different_link"))
    end
  end
end
