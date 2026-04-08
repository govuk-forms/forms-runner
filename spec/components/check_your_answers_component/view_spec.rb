require "rails_helper"

RSpec.describe CheckYourAnswersComponent::View, type: :component do
  include Rails.application.routes.url_helpers

  let(:form) { build :form, id: 1 }
  let(:question) { build :text, question_text: "Do you want to remain anonymous?", text: "Yes" }
  let(:optional_question) { build :text, question_text: "Optional question", is_optional: true, text: "" }
  let(:steps) do
    [
      build(:step, question: question, form_document_step: build(:v2_question_step, :with_text_settings)),
      build(:step, question: optional_question, form_document_step: build(:v2_question_step, :with_text_settings)),
    ]
  end
  let(:mode) { Mode.new("form") }

  before do
    render_inline(described_class.new(form:, steps:, mode:))
  end

  it "renders a row for each step" do
    expect(page).to have_css(".govuk-summary-list__row", count: 2)
  end

  it "displays the question text and answer for each step" do
    expect(page).to have_css(".govuk-summary-list__key", text: "Do you want to remain anonymous?")
    expect(page).to have_css(".govuk-summary-list__value", text: "Yes")
    expect(page).to have_css(".govuk-summary-list__key", text: "Optional question (optional)")
    expect(page).to have_css(".govuk-summary-list__value", text: "Not completed")
  end

  it "displays the question text with '(optional)' for optional questions" do
    expect(page).to have_xpath "(//dl)/div[1]/dt", text: "Do you want to remain anonymous?"
    expect(page).to have_xpath "(//dl)/div[2]/dt", text: "Optional question (optional)"
  end

  it "displays the answer for answered question" do
    expect(page).to have_xpath "(//dl)/div[1]/dd", text: "Yes"
  end

  it "displays 'Not completed' for unanswered optional questions" do
    expect(page).to have_xpath "(//dl)/div[2]/dd", text: "Not completed"
  end

  it "includes change links for each step" do
    expect(page).to have_link("Change", href: form_change_answer_path(mode: mode, form_id: form.id, form_slug: form.form_slug, step_slug: steps[0].id))
    expect(page).to have_link("Change", href: form_change_answer_path(mode: mode, form_id: form.id, form_slug: form.form_slug, step_slug: steps[1].id))
  end

  context "when a step is repeatable and has an answer" do
    let(:steps) { [build(:repeatable_step, question: question, form_document_step: build(:v2_question_step, :with_text_settings))] }

    it "uses the add another answer path for the change link" do
      expect(page).to have_link("Change", href: change_add_another_answer_path(mode: mode, form_id: form.id, form_slug: form.form_slug, step_slug: steps[0].id))
    end
  end

  context "when there is a long_text text question" do
    let(:question) { build :text, :with_long_text, question_text: "Do you want to remain anonymous?" }

    it "displays the summary list full width" do
      expect(page).not_to have_css(".govuk-grid-column-two-thirds-from-desktop .govuk-summary-list")
      expect(page).to have_css(".govuk-grid-column-full .govuk-summary-list")
    end
  end

  context "when there is no long_text text question" do
    it "displays the summary list at two-thirds width" do
      expect(page).not_to have_css(".govuk-grid-column-full .govuk-summary-list")
      expect(page).to have_css(".govuk-grid-column-two-thirds-from-desktop .govuk-summary-list")
    end
  end

  context "when there is a file upload question with a page heading" do
    let(:question) { build :file, :with_uploaded_file, question_text: "Do you want to remain anonymous?", page_heading: "A heading" }

    it "displays the page heading as a caption" do
      expect(page).to have_css("span.govuk-caption-m", text: question.page_heading)
    end
  end

  context "when there is a selection question with a 'None of the above' question" do
    let(:question_text) { "Select an option" }
    let(:none_of_the_above_question_text) { "What would you pick then?" }
    let(:selection) { nil }
    let(:none_of_the_above_answer) { nil }
    let(:none_of_the_above_question_is_optional) { "false" }
    let(:selection_options) { [DataStruct.new(name: "Option 1", value: "Option 1"), DataStruct.new(name: "Option 2", value: "Option 2")] }
    let(:question) do
      build(
        :single_selection_question,
        :with_none_of_the_above_question,
        question_text:,
        selection_options:,
        none_of_the_above_question_text:,
        selection:,
        none_of_the_above_answer:,
        none_of_the_above_question_is_optional:,
      )
    end

    context "when 'None of the above' is not selected" do
      it "does not display the 'None of the above' question in the answers" do
        expect(page).to have_css(".govuk-summary-list__key", text: question_text)
        expect(page).not_to have_css(".govuk-summary-list__key", text: none_of_the_above_question_text)
      end
    end

    context "when 'None of the above' is selected" do
      let(:selection) { "None of the above" }

      context "and an answer is provided for the 'None of the above' question" do
        let(:none_of_the_above_answer) { "This one" }

        it "displays the 'None of the above' question and answer in the answers" do
          expect(page).to have_css(".govuk-summary-list__key", text: question_text)
          expect(page).to have_css(".govuk-summary-list__value", text: selection)
          expect(page).to have_css(".govuk-summary-list__key", text: none_of_the_above_question_text)
          expect(page).to have_css(".govuk-summary-list__value", text: none_of_the_above_answer)
        end

        it "has a change link for the 'None of the above' question" do
          expect(page).to have_link("Change", href: form_change_answer_path(mode: mode, form_id: form.id, form_slug: form.form_slug, step_slug: steps[0].id))
        end
      end

      context "when 'None of the above' question is optional" do
        let(:none_of_the_above_question_is_optional) { "true" }

        it "displays '(optional)' in the 'None of the above' question text" do
          expect(page).to have_css(".govuk-summary-list__key", text: "#{none_of_the_above_question_text} (optional)")
        end

        context "and no answer is provided for the 'None of the above' question" do
          it "displays 'Not completed' for the 'None of the above' question" do
            expect(page).to have_css(".govuk-summary-list__value", text: "Not completed")
          end
        end
      end

      context "when selection question uses an autocomplete component" do
        let(:selection_options) { Array.new(31).map { |i| OpenStruct.new(name: "Option #{i}", value: "Option #{i}") } }

        it "has a change link to the 'None of the above' specific path" do
          expect(page).to have_link("Change", href: change_selection_none_of_the_above_path(mode: mode, form_id: form.id, form_slug: form.form_slug, step_slug: steps[0].id))
        end
      end
    end
  end
end
