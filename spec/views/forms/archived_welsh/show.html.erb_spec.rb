require "rails_helper"

describe "forms/archived_welsh/show.html.erb" do
  let(:form_document) { build :v2_form_document, name: "Archived Welsh form" }
  let(:form) { Form.new(form_document) }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }

  before do
    assign(:mode, mode)
    allow(view).to receive(:form_path).and_return("/form/1/english_form")

    render template: "forms/archived_welsh/show", locals: { form: }, status: :not_found
  end

  it "has the correct title" do
    expect(view.content_for(:title)).to eq "#{t('forms.archived_welsh.show.heading')} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: t("forms.archived_welsh.show.heading"))
  end

  it "displays the body text" do
    expect(rendered).to have_text(I18n.t("forms.archived_welsh.show.welsh_version_archived"))
  end

  it "displays a link to the English form" do
    expect(rendered).to have_text(I18n.t("forms.archived_welsh.show.view_english_form"))
    expect(rendered).to have_link("Archived Welsh form", href: "/form/1/english_form")
  end
end
