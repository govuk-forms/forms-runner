require "rails_helper"

describe "forms/save_progress/show.html.erb" do
  let(:form) { build :form, save_and_return: "enabled" }
  let(:one_login_email) { "test@example.com" }
  let(:deletion_date) { "13/11/2026" }
  let(:form_url) { "http://www.example.com/form/#{form.id}/#{form.form_slug}" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:one_login_email, one_login_email)
    assign(:deletion_date, deletion_date)

    allow(view).to receive(:form_url).with(form.id, form.form_slug).and_return(form_url)

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.save_progress.show.title')} - #{form.name}"
  end

  it "has a success notification banner with the heading" do
    expect(rendered).to have_css(".govuk-notification-banner--success", text: I18n.t("forms.save_progress.show.title"))
  end

  it "has the body text" do
    expect(rendered).to include(I18n.t("forms.save_progress.show.body_html", email: one_login_email, deletion_date:, form_url:))
  end

  it "has the deletion date" do
    expect(rendered).to include("We'll delete your saved form on #{deletion_date}.")
  end

  it "has a link to continue filling in the form" do
    expect(rendered).to have_link(form_url, href: form_url)
  end

  it "has a link to sign out of GOV.UK One Login" do
    expect(rendered).to have_link(I18n.t("forms.save_progress.show.sign_out_link"))
  end

  it "does not have a back link" do
    expect(view.content_for(:back_link)).to be_nil
  end
end
