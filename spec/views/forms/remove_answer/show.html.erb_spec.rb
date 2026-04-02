require "rails_helper"

describe "forms/remove_answer/show.html.erb" do
  let(:form) { Form.new(build(:v2_form_document)) }
  let(:mode) { OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false) }
  let(:question) { OpenStruct.new({ allow_multiple_answers?: allow_multiple_answers?, has_long_answer?: has_long_answer? }) }
  let(:step) { OpenStruct.new({ form_id: 1, form_slug: "form-1", step_slug: "1", questions:, question:, answer_index: 1, mode: }) }
  let(:remove_input) { RemoveInput.new }
  let(:questions) { [{ text: "answer" }] }
  let(:answer_index) { 1 }
  let(:allow_multiple_answers?) { false }
  let(:has_long_answer?) { false }
  let(:phone_number) { false }
  let(:national_insurance_number) { false }
  let(:address) { false }
  let(:selection) { false }
  let(:form_path) { "form1/etc" }

  before do
    assign(:current_context, OpenStruct.new(form:))
    assign(:form, form)
    assign(:mode, mode)
    assign(:step, step)
    assign(:remove_input, remove_input)

    without_partial_double_verification do
      allow(view).to receive_messages(delete_form_remove_answer_path: "/remove", add_another_answer_path: "/back")
    end

    allow(question).to receive(:is_a?).with(Question::PhoneNumber).and_return(phone_number)
    allow(question).to receive(:is_a?).with(Question::NationalInsuranceNumber).and_return(national_insurance_number)
    allow(question).to receive(:is_a?).with(Question::Address).and_return(address)
    allow(question).to receive(:is_a?).with(Question::Selection).and_return(selection)

    render
  end

  it "has a back link" do
    expect(view.content_for(:back_link)).to have_link("Back", href: "/back")
  end

  context "when there are errors" do
    before do
      remove_input.errors.add(:base, "Error message")
    end

    it "renders the error summary" do
      render
      expect(rendered).to have_css(".govuk-error-summary")
    end
  end

  context "when the question type is a phone number" do
    let(:phone_number) { true }

    it "shows the phone number heading" do
      render
      expect(rendered).to have_content("Remove phone number")
    end
  end

  context "when the question type is a National Insurance number" do
    let(:national_insurance_number) { true }

    it "shows the National Insurance number heading" do
      render
      expect(rendered).to have_content("Remove National Insurance number")
    end
  end

  context "when the question type is an Address" do
    let(:address) { true }

    it "shows the address heading" do
      render
      expect(rendered).to have_content("Remove an address")
    end
  end

  context "when the question type is selection and allows multiple answers" do
    let(:selection) { true }
    let(:allow_multiple_answers?) { true }

    it "shows the long answer heading" do
      render
      expect(rendered).to have_content("Remove an answer")
    end
  end

  context "when the question has a long answer" do
    let(:has_long_answer?) { true }

    it "shows the long answer heading" do
      render
      expect(rendered).to have_content("Remove an answer")
    end
  end

  context "when the question has a short answer" do
    it "shows the short answer heading" do
      render
      expect(rendered).to have_content("Are you sure you want to remove")
    end
  end
end
