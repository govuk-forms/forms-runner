require "rails_helper"

describe "forms/exit_pages/show.html.erb" do
  let(:form) { build :form, :with_support, name: "exit page form" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:condition) { OpenStruct.new({ exit_page_heading: "heading", exit_page_markdown: "  * first line\n  * second line\n" }) }
  let(:support_details) { OpenStruct.new(email: form.support_email) }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:mode, mode)
    assign(:condition, condition)
    assign(:back_link, "/back")
    assign(:support_details, support_details)

    render
  end

  it "has the correct title" do
    expect(view.content_for(:title)).to eq "heading - exit page form"
  end

  it "has a back link" do
    expect(view.content_for(:back_link)).to have_link("Back", href: "/back")
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: condition.exit_page_heading)
  end

  it "displays the markdown" do
    expect(rendered).to have_css("li", text: "second line")
  end

  it "displays the help link" do
    expect(rendered).to have_text(I18n.t("support_details.get_help_with_this_form"))
  end
end
