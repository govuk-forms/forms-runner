require "rails_helper"

RSpec.describe Question::DateComponent::View, type: :component do
  let(:form_document_step) { build :v2_question_page_step, :with_date_settings, input_type: }
  let(:input_type) { "other_date" }
  let(:question_attributes) { { date_day: nil, date_month: nil, date_year: nil } }
  let(:question) do
    Question::Date.new(question_attributes, {
      question_text: form_document_step.question_text,
      hint_text: form_document_step.hint_text,
      answer_settings:,
      page_heading: form_document_step.page_heading,
      guidance_markdown: form_document_step.guidance_markdown,
    })
  end
  let(:answer_settings) { form_document_step.answer_settings }
  let(:mode) { Mode.new("form") }
  let(:form_builder) do
    GOVUKDesignSystemFormBuilder::FormBuilder.new(:form, question,
                                                  ActionView::Base.new(ActionView::LookupContext.new(nil), {}, nil), {})
  end

  before do
    render_inline(described_class.new(form_builder:, question:, mode:))
  end

  describe "when component is other date field" do
    it "renders the question text as a heading" do
      expect(page.find("legend h1")).to have_text(question.question_text_with_optional_suffix)
    end

    it "renders 3 text fields (day, month, year)" do
      expect(page).to have_css("input[type='text'][name='form[date(3i)]']")
      expect(page).to have_css("input[type='text'][name='form[date(2i)]']")
      expect(page).to have_css("input[type='text'][name='form[date(1i)]']")
    end

    it "does not contain autocomplete attributes" do
      expect(page).not_to have_css("input[type='text'][autocomplete='bday-day']")
      expect(page).not_to have_css("input[type='text'][autocomplete='bday-month']")
      expect(page).not_to have_css("input[type='text'][autocomplete='bday-year']")
    end

    context "when the user has provided an answer" do
      let(:question_attributes) { { date_day: 31, date_month: 1, date_year: 2023 } }

      it "sets the 3 text fields (day,month, year) value" do
        expect(page.find("input[type='text'][name='form[date(3i)]']").value).to eq "31"
        expect(page.find("input[type='text'][name='form[date(2i)]']").value).to eq "1"
        expect(page.find("input[type='text'][name='form[date(1i)]']").value).to eq "2023"
      end
    end

    context "when the question has hint text" do
      let(:form_document_step) { build :v2_question_page_step, :with_hints, :with_date_settings, input_type: }

      it "outputs the hint text" do
        expect(page.find(".govuk-hint")).to have_text(question.hint_text)
      end
    end

    context "when there is extra suffix to be added to heading" do
      let(:mode) { Mode.new("preview-draft") }

      it "renders the question text and extra suffix as a heading" do
        expect(page.find("legend h1").native.inner_html).to eq("#{question.question_text} <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>")
      end
    end

    context "with unsafe question text" do
      let(:form_document_step) { build :v2_question_page_step, :with_date_settings, input_type:, question_text: "What is your name? <script>alert(\"Hi\")</script>" }
      let(:mode) { Mode.new("preview-draft") }

      it "returns the escaped title with the optional suffix" do
        expected_output = "What is your name? &lt;script&gt;alert(\"Hi\")&lt;/script&gt; <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>"
        expect(page.find("h1").native.inner_html).to eq(expected_output)
      end
    end

    context "when question has guidance" do
      let(:form_document_step) { build :v2_question_page_step, :with_guidance, :with_date_settings }

      it "renders the question text as a legend" do
        expect(page.find("legend.govuk-fieldset__legend--m")).to have_text(form_document_step.question_text)
      end
    end
  end

  describe "when component is date of birth field" do
    let(:input_type) { "date_of_birth" }

    it "renders the question text as a heading" do
      expect(page.find("legend h1")).to have_text(question.question_text_with_optional_suffix)
    end

    it "renders 3 text fields (day, month, year)" do
      expect(page).to have_css("input[type='text'][name='form[date(3i)]']")
      expect(page).to have_css("input[type='text'][name='form[date(2i)]']")
      expect(page).to have_css("input[type='text'][name='form[date(1i)]']")
    end

    it "does contain autocomplete attributes" do
      expect(page).to have_css("input[type='text'][autocomplete='bday-day']")
      expect(page).to have_css("input[type='text'][autocomplete='bday-month']")
      expect(page).to have_css("input[type='text'][autocomplete='bday-year']")
    end

    context "when the user has provided an answer" do
      let(:question_attributes) { { date_day: 31, date_month: 1, date_year: 2023 } }

      it "sets the 3 text fields (day,month, year) value" do
        expect(page.find("input[type='text'][name='form[date(3i)]']").value).to eq "31"
        expect(page.find("input[type='text'][name='form[date(2i)]']").value).to eq "1"
        expect(page.find("input[type='text'][name='form[date(1i)]']").value).to eq "2023"
      end
    end

    context "when the question has hint text" do
      let(:form_document_step) { build :v2_question_page_step, :with_hints, :with_date_settings, input_type: }

      it "outputs the hint text" do
        expect(page.find(".govuk-hint")).to have_text(question.hint_text)
      end
    end

    context "when the mode is preview" do
      let(:mode) { Mode.new("preview-draft") }

      it "renders the question text and extra suffix as a heading" do
        expect(page.find("h1").native.inner_html).to eq("#{question.question_text} <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>")
      end
    end

    context "with unsafe question text" do
      let(:form_document_step) { build :v2_question_page_step, :with_date_settings, input_type:, question_text: "What is your name? <script>alert(\"Hi\")</script>" }
      let(:mode) { Mode.new("preview-draft") }

      it "returns the escaped title with the optional suffix" do
        expected_output = "What is your name? &lt;script&gt;alert(\"Hi\")&lt;/script&gt; <span class=\"govuk-visually-hidden\">\u{00A0}#{I18n.t('page.draft_preview')}</span>"
        expect(page.find("legend h1").native.inner_html).to eq(expected_output)
      end
    end

    context "when question has guidance" do
      let(:form_document_step) { build :v2_question_page_step, :with_guidance, :with_date_settings }

      it "renders the question text as a legend" do
        expect(page.find("legend.govuk-fieldset__legend--m")).to have_text(form_document_step.question_text)
      end
    end
  end

  context "when answer_settings is nil - behaves like other dates" do
    let(:answer_settings) { nil }

    it "renders the question text as a heading" do
      expect(page.find("legend h1")).to have_text(question.question_text_with_optional_suffix)
    end

    it "renders 3 text fields (day, month, year)" do
      expect(page).to have_css("input[type='text'][name='form[date(3i)]']")
      expect(page).to have_css("input[type='text'][name='form[date(2i)]']")
      expect(page).to have_css("input[type='text'][name='form[date(1i)]']")
    end

    it "does not contain autocomplete attributes" do
      expect(page).not_to have_css("input[type='text'][autocomplete='bday-day']")
      expect(page).not_to have_css("input[type='text'][autocomplete='bday-month']")
      expect(page).not_to have_css("input[type='text'][autocomplete='bday-year']")
    end

    context "when question has guidance" do
      let(:form_document_step) { build :v2_question_page_step, :with_guidance, answer_type: "date", answer_settings: }

      it "renders the question text as a legend" do
        expect(page.find("legend.govuk-fieldset__legend--m")).to have_text(form_document_step.question_text)
      end
    end
  end
end
