require "rails_helper"

RSpec.describe Question::TextComponent::View, type: :component do
  let(:form_document_step) { build :v2_question_page_step, :with_text_settings, input_type: }
  let(:input_type) { "single_line" }
  let(:answer_text) { nil }
  let(:question) do
    build(:text,
          text: answer_text,
          question_text: form_document_step.question_text,
          hint_text: form_document_step.hint_text,
          answer_settings: form_document_step.answer_settings,
          page_heading: form_document_step.page_heading,
          guidance_markdown: form_document_step.guidance_markdown)
  end
  let(:mode) { Mode.new("form") }
  let(:form_builder) do
    GOVUKDesignSystemFormBuilder::FormBuilder.new(:form, question,
                                                  ActionView::Base.new(ActionView::LookupContext.new(nil), {}, nil), {})
  end

  before do
    render_inline(described_class.new(form_builder:, question:, mode:))
  end

  describe "when component is short answer text field" do
    it "renders the question text as a heading" do
      expect(page.find("h1 label")).to have_text(question.question_text_with_optional_suffix)
    end

    it "renders a text input field" do
      expect(page).to have_css("input[type='text'][name='form[text]']")
    end

    context "when the user has provided an answer" do
      let(:answer_text) { Faker::Quote.yoda }

      it "sets the field value" do
        expect(page.find("input[type='text'][name='form[text]']").value).to eq answer_text
      end
    end

    context "when the question has hint text" do
      let(:form_document_step) { build :v2_question_page_step, :with_hints, :with_text_settings, input_type: }

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
      let(:form_document_step) { build :v2_question_page_step, :with_text_settings, input_type:, question_text: "What is your name? <script>alert(\"Hi\")</script>" }
      let(:mode) { Mode.new("preview-draft") }

      it "returns the escaped title with the optional suffix" do
        expected_output = "What is your name? &lt;script&gt;alert(\"Hi\")&lt;/script&gt; <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>"
        expect(page.find("h1 .govuk-label").native.inner_html).to eq(expected_output)
      end
    end

    context "when question has guidance" do
      let(:form_document_step) { build :v2_question_page_step, :with_text_settings, :with_guidance, input_type: }

      it "renders the question text as a label" do
        expect(page.find("label.govuk-label--m")).to have_text(form_document_step.question_text)
      end
    end
  end

  describe "when component is multi-line answer" do
    let(:input_type) { "long_text" }

    it "renders the question text as a heading" do
      expect(page.find("h1 label")).to have_text(question.question_text_with_optional_suffix)
    end

    it "renders a textarea field" do
      expect(page).to have_css("textarea[name='form[text]']")
    end

    it "renders textarea with 5 rows" do
      expect(page).to have_css("textarea[rows='5']")
    end

    context "when the user has provided an answer" do
      let(:answer_text) { Faker::Quote.yoda }

      it "sets the field value" do
        expect(page.find("textarea[name='form[text]']").value).to eq answer_text
      end
    end

    context "when the question has hint text" do
      let(:form_document_step) { build :v2_question_page_step, :with_hints, :with_text_settings, input_type: }

      it "outputs the hint text" do
        expect(page.find(".govuk-hint")).to have_text(question.hint_text)
      end
    end

    context "with unsafe question text" do
      let(:form_document_step) { build :v2_question_page_step, :with_text_settings, input_type:, question_text: "What is your name? <script>alert(\"Hi\")</script>" }
      let(:mode) { Mode.new("preview-draft") }

      it "returns the escaped title with the optional suffix" do
        expected_output = "What is your name? &lt;script&gt;alert(\"Hi\")&lt;/script&gt; <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>"
        expect(page.find("h1 .govuk-label").native.inner_html).to eq(expected_output)
      end
    end

    context "when the mode is preview" do
      let(:mode) { Mode.new("preview-draft") }

      it "renders the question text and extra suffix as a heading" do
        expect(page.find("h1 label").native.inner_html).to eq("#{question.question_text} <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>")
      end
    end

    context "when question has guidance" do
      let(:form_document_step) { build :v2_question_page_step, :with_text_settings, :with_guidance, input_type: }

      it "renders the question text as a label" do
        expect(page.find("label.govuk-label--m")).to have_text(form_document_step.question_text)
      end
    end
  end
end
