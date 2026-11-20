require "rails_helper"

describe "forms/continue_saved_form/new.html.erb" do
  let(:form) { build :form, save_and_return: "enabled", start_page: 1 }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:resume_options_path) { "/form/#{form.id}/#{form.form_slug}/what-do-you-want-to-do" }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)

    allow(view).to receive_messages(resume_options_path:)

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.continue_saved_form.new.title')} - #{form.name}"
  end

  it "has a back link to the page asking whether to start a new form or continue a saved one" do
    expect(view.content_for(:back_link)).to have_link(I18n.t("forms.back"), href: resume_options_path)
  end

  it "has a button to continue to GOV.UK One Login" do
    expect(rendered).to have_button(I18n.t("forms.continue_saved_form.new.continue_to_one_login_button"))
  end
end
