require "rails_helper"

describe "forms/add_another_answer/show.html.erb" do
  let(:form) { build :form, id: 1 }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:step) { OpenStruct.new({ form_id: 1, form_slug: "form-1", step_slug: "1", mode:, questions:, question: OpenStruct.new({ question_text: "Question text" }), max_answers?: max_answers }) }
  let(:add_another_answer_input) { AddAnotherAnswerInput.new }
  let(:back_link) { "/back" }
  let(:questions) { [] }
  let(:max_answers) { false }

  let(:rows) { [{ key: { text: "Row 1" }, value: { text: "Value 1" } }] }

  let(:form_path) { "form1/etc" }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:rows, rows)
    assign(:step, step)
    assign(:back_link, back_link)
    assign(:add_another_answer_input, add_another_answer_input)

    without_partial_double_verification do
      allow(view).to receive(:add_another_answer_path).and_return("/add_another_answer")
    end

    render
  end

  it "has the correct page title" do
    expect(view.content_for(:title)).to eq "Add or remove answer to Question text - #{form.name}"
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

  it "has the correct heading" do
    expect(rendered).to have_content("You have added one answer")
  end

  it "displays rows" do
    expect(rendered).to have_content("Row 1")
    expect(rendered).to have_content("Value 1")
  end

  context "when there are errors" do
    before do
      add_another_answer_input.errors.add(:base, "Error message")
    end

    it "renders the error summary" do
      render
      expect(rendered).to have_css(".govuk-error-summary")
    end
  end

  context "when the maximum number of answers have been added" do
    let(:max_answers) { true }

    it "renders the max answers text" do
      expect(rendered).to have_content("You cannot add another answer to this question as you’ve entered the maximum of 50")
    end
  end
end
