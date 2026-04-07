require "rails_helper"

RSpec.describe Question::NationalInsuranceNumberComponent::View, type: :component do
  let(:form_document_step) { build :v2_question_page_step, answer_type: "national_insurance_number" }
  let(:national_insurance_number) { nil }
  let(:question) do
    Question::NationalInsuranceNumber.new({ national_insurance_number: national_insurance_number }, {
      question_text: form_document_step.question_text,
      hint_text: form_document_step.hint_text,
      answer_settings: nil,
      page_heading: form_document_step.page_heading,
      guidance_markdown: form_document_step.guidance_markdown,
    })
  end
  let(:mode) { Mode.new("form") }
  let(:form_builder) do
    GOVUKDesignSystemFormBuilder::FormBuilder.new(:form, question,
                                                  ActionView::Base.new(ActionView::LookupContext.new(nil), {}, nil), {})
  end

  before do
    render_inline(described_class.new(form_builder:, question:, mode:))
  end

  describe "when component is national insurance number field" do
    it "renders the question text as a heading" do
      expect(page.find("h1")).to have_text(question.question_text_with_optional_suffix)
    end

    it "renders a text input field" do
      expect(page).to have_css("input[type='text'][name='form[national_insurance_number]']")
    end

    it "renders at 10-character width (https://design-system.service.gov.uk/components/text-input/#fixed-width-inputs)" do
      expect(page.native.to_html).to include('class="govuk-input govuk-input--width-10"')
    end

    context "when the user has provided an answer" do
      let(:national_insurance_number) { 8 }

      it "sets the field value" do
        expect(page.find("input[type='text'][name='form[national_insurance_number]']").value).to eq national_insurance_number.to_s
      end
    end

    context "when the question has hint text" do
      let(:form_document_step) { build :v2_question_page_step, :with_hints, answer_type: "national_insurance_number" }

      it "outputs the hint text" do
        expect(page.find(".govuk-hint")).to have_text(question.hint_text)
      end
    end

    context "when the mode is preview" do
      let(:mode) { Mode.new("preview-draft") }

      it "renders the question text and extra suffix as a heading" do
        expect(page.find("h1 label").native.inner_html).to eq("#{question.question_text} <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>")
      end
    end

    context "with unsafe question text" do
      let(:form_document_step) { build :v2_question_page_step, answer_type: "national_insurance_number", question_text: "What is your name? <script>alert(\"Hi\")</script>" }
      let(:mode) { Mode.new("preview-draft") }

      it "returns the escaped title with the optional suffix" do
        expected_output = "What is your name? &lt;script&gt;alert(\"Hi\")&lt;/script&gt; <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>"
        expect(page.find("h1 .govuk-label").native.inner_html).to eq(expected_output)
      end
    end

    context "when question has guidance" do
      let(:form_document_step) { build :v2_question_page_step, :with_guidance, answer_type: "national_insurance_number" }

      it "renders the question text as a label" do
        expect(page.find("label.govuk-label--m")).to have_text(form_document_step.question_text)
      end
    end
  end
end
