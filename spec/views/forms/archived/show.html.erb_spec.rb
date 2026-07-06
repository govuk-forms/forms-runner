require "rails_helper"

describe "forms/archived/show.html.erb" do
  let(:form) { build :form, name: "Archived form" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }

  before do
    assign(:form, form)
    assign(:mode, mode)

    render template: "forms/archived/show", locals: { form_name: form.name }, status: :gone
  end

  it "has the correct title" do
    expect(view.content_for(:title)).to eq "Sorry, this service is no longer available - Archived form"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: t("form.archived.heading"))
  end

  it "displays the body text" do
    expect(rendered).to have_text(I18n.t("form.archived.service_unavailable", form_name: form.name))
  end
end
