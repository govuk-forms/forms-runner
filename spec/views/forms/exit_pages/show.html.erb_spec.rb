require "rails_helper"

describe "forms/exit_pages/show.html.erb" do
  let(:exit_page) do
    ExitPage.new(
      id: 99,
      heading: "heading",
      markdown: "  * first line\n  * second line\n",
    )
  end

  let(:form) { build :form, :with_support, name: "exit page form" }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:support_details) { OpenStruct.new(email: form.support_email) }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:mode, mode)
    assign(:back_link, "/back")
    assign(:support_details, support_details)
    assign(:exit_page, exit_page)

    render
  end

  it "has the correct title" do
    expect(view.content_for(:title)).to eq "heading - exit page form"
  end

  it "has a back link" do
    expect(view.content_for(:back_link)).to have_link("Back", href: "/back")
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: exit_page.heading)
  end

  it "displays the markdown" do
    expect(rendered).to have_css("li", text: "second line")
  end

  it "displays the help link" do
    expect(rendered).to have_text(I18n.t("support_details.get_help_with_this_form"))
  end
end
