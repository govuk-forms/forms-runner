require "rails_helper"

describe "forms/save_progress/show.html.erb" do
  let(:form) { build :form, save_and_return: "enabled" }
  let(:one_login_email) { "test@example.com" }
  let(:deletion_date) { Time.zone.local(2026, 11, 13, 10, 30) }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:continue_path) { "/form/#{form.id}/#{form.form_slug}/2" }
  let(:logged_in) { true }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:one_login_email, one_login_email)
    assign(:deletion_date, deletion_date)
    assign(:continue_path, continue_path)
    assign(:auth_service, instance_double(AuthService, logged_in?: logged_in))

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.save_progress.show.title')} - #{form.name}"
  end

  it "has the heading" do
    expect(rendered).to have_css("h1", text: I18n.t("forms.save_progress.show.title"))
  end

  it "has the body text" do
    expect(rendered).to include(I18n.t("forms.save_progress.show.body_html", email: one_login_email, deletion_date: "13 November 2026"))
  end

  it "has the deletion date" do
    expect(rendered).to include("We’ll delete your saved form on 13 November 2026.")
  end

  it "has a button to continue filling the form" do
    expect(rendered).to have_link(I18n.t("forms.save_progress.show.continue_button"), href: continue_path, class: "govuk-button")
  end

  it "has a button to sign out of GOV.UK One Login" do
    expect(rendered).to have_button(I18n.t("sign_out_of_govuk_one_login")) do |button|
      expect(button).to match_css ".govuk-button--secondary"
      expect(button.ancestor("form")[:action]).to eq omniauth_logout_path
    end
  end

  context "when the user is not logged in" do
    let(:logged_in) { false }

    it "does not have a button to sign out of GOV.UK One Login" do
      expect(rendered).not_to have_button(I18n.t("sign_out_of_govuk_one_login"))
    end
  end

  it "does not have a back link" do
    expect(view.content_for(:back_link)).to be_nil
  end
end
