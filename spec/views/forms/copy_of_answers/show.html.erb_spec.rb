require "rails_helper"

describe "forms/copy_of_answers/show.html.erb" do
  let(:form) { build :form }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:copy_of_answers_input) { CopyOfAnswersInput.new }
  let(:back_link) { "/back" }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:back_link, back_link)
    assign(:copy_of_answers_input, copy_of_answers_input)

    without_partial_double_verification do
      allow(view).to receive(:save_copy_of_answers_path).and_return("/save_copy_of_answers")
    end

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "#{I18n.t('forms.copy_of_answers.show.title')} - #{form.name}"
  end

  it "has the correct heading" do
    expect(rendered).to have_css("h1", text: I18n.t("forms.copy_of_answers.show.heading"))
  end

  it "has the hint text" do
    expect(rendered).to have_content(I18n.t("forms.copy_of_answers.show.hint"))
  end

  it "has a back link" do
    expect(view.content_for(:back_link)).to have_link("Back", href: "/back")
  end

  it "displays Yes and No radio options" do
    expect(rendered).to have_field("Yes")
    expect(rendered).to have_field("No")
  end

  it "has a continue button" do
    expect(rendered).to have_button(I18n.t("continue"))
  end

  context "when back link not present" do
    let(:back_link) { "" }

    it "does not set back link" do
      expect(view.content_for(:back_link)).to be_nil
    end
  end

  context "when there are errors" do
    before do
      copy_of_answers_input.valid?
      render
    end

    it "renders the error summary" do
      expect(rendered).to have_css(".govuk-error-summary")
    end

    it "displays the error message" do
      expect(rendered).to have_content("Select")
      expect(rendered).to have_content("Yes")
      expect(rendered).to have_content("copy of your answers")
    end
  end
end
