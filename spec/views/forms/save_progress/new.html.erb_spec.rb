require "rails_helper"

describe "forms/save_progress/new.html.erb" do
  let(:form) { build :form, save_and_return: "enabled" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:sign_in_again) { nil }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:back_link, "/previous-step")
    assign(:sign_in_again, sign_in_again)

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

  it "has the body text" do
    expect(rendered).to include(I18n.t("forms.save_progress.new.body_html"))
  end

  it "has a button that posts to GOV.UK One Login" do
    expect(rendered).to have_css("form[action='/auth/govuk_one_login'][method='post']")
    expect(rendered).to have_button(I18n.t("forms.save_progress.new.continue_to_one_login_button"))
  end

  context "when the user is signing in to a different GOV.UK One Login" do
    let(:sign_in_again) { true }

    it "has the sign in again page title" do
      expect(view.content_for(:title)).to eq "#{I18n.t('forms.save_progress.new.sign_in_again_title')} - #{form.name}"
    end

    it "has the sign in again heading" do
      expect(rendered).to have_css("h1", text: I18n.t("forms.save_progress.new.sign_in_again_title"))
    end
  end
end
