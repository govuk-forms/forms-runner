require "rails_helper"

describe "forms/review_file/show.html.erb" do
  let(:form) { build :form, :with_support }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:back_link) { "/back" }
  let(:continue_url) { "/review_file" }
  let(:remove_file_url) { "/remove_file" }
  let(:question) { build :file, :with_uploaded_file }
  let(:step) { build :step, question: }
  let(:support_details) { OpenStruct.new({ email: "help@example.gov.uk", phone: "Call 01610123456\n\nThis line is only open on Tuesdays.", url: "https://example.gov.uk/contact", url_text: "Contact form" }) }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:mode, mode)
    assign(:step, step)
    assign(:back_link, back_link)
    assign(:continue_url, continue_url)
    assign(:remove_file_url, remove_file_url)
    assign(:support_details, support_details)

    without_partial_double_verification do
      allow(view).to receive(:remove_file_path).and_return("/remove_file")
    end

    render
  end

  it "has a back link" do
    expect(view.content_for(:back_link)).to have_link("Back", href: "/back")
  end

  context "when back link not preset" do
    let(:back_link) { "" }

    it "does not set back link" do
      expect(view.content_for(:back_link)).to be_nil
    end
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.review_file.show.check_file')} - #{question.question_text} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: question.question_text)
  end

  it "displays the review file component with the uploaded file name" do
    expect(rendered).to have_content(question.original_filename)
  end

  it "has a continue button" do
    page = Capybara.string(rendered.html)
    within(page.find("form[action='#{continue_url}'][method='post']")) do
      expect(page).to have_button("Continue")
    end
  end
end
