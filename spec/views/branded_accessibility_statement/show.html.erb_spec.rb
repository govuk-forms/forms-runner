require "rails_helper"

describe "forms/branded_accessibility_statement/show.html.erb" do
  let(:form) { build :form, brand_id: "cheshire-east" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }

  before do
    render template: "forms/branded_accessibility_statement/show"
  end

  it "has the correct title" do
    expect(view.content_for(:title)).to eq "Accessibility statement – GOV.UK Forms"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: "Accessibility statement for this form")
  end

  it "displays the body text" do
    expect(rendered).to have_text(I18n.t("accessibility_statement.preamble_branded"))
  end
end
