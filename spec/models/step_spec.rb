require "rails_helper"

RSpec.describe Step do
  subject(:step) do
    described_class.new(
      question:,
      form_document_step:,
    )
  end

  let(:step_ids) { Array.new(4) { Faker::Alphanumeric.alphanumeric(number: 8) } }
  let(:first_step_id) { step_ids[0] }
  let(:second_step_id) { step_ids[1] }
  let(:third_step_id) { step_ids[2] }
  let(:fourth_step_id) { step_ids[3] }

  let(:question) { instance_double(Question::Text, serializable_hash: {}, attribute_names: %w[name], valid?: true, errors: []) }
  let(:form_document_step) { build(:form_document_step, id: first_step_id, position: 1, next_page: second_step_id, routing_conditions: []) }
  let(:answer_store) { instance_double(Store::SessionAnswerStore) }
  let(:form) { build(:form, id: 3, form_slug: "test-form", form_document_steps: [form_document_step]) }

  describe "#initialize" do
    it "sets the attributes correctly" do
      expect(step.question).to eq(question)
      expect(step.id).to eq(first_step_id)
      expect(step.next_step_slug).to eq(second_step_id)
      expect(step.page_number).to eq(1)
      expect(step.routing_conditions).to eq([])
    end
  end

  describe "#==" do
    it "returns true for steps with the same state" do
      other_step = described_class.new(
        question:,
        form_document_step:,
      )
      expect(step).to eq(other_step)
    end

    it "returns false for steps with different states" do
      other_step = described_class.new(
        question:,
        form_document_step: build(:form_document_step),
      )
      expect(step == other_step).to be false
    end
  end

  describe "#state" do
    it "returns an array of instance variable values" do
      expected_state = [
        step.form_document_step,
        step.question,
      ]

      expect(step.state).to match_array(expected_state)
    end

    it "changes when an instance variable is modified" do
      original_state = step.state.dup
      step.form_document_step = build(:form_document_step, position: 2)
      expect(step.state).not_to eq(original_state)
    end
  end

  describe "#save_to_context" do
    it "saves the step to the form context" do
      expect(question).to receive(:before_save)
      expect(answer_store).to receive(:save_step).with(step, {})
      step.save_to_store(answer_store)
    end

    context "when errors are added to the question by before_save" do
      before do
        errors = instance_double(ActiveModel::Errors, empty?: false)
        allow(question).to receive(:errors).and_return(errors)
        allow(question).to receive(:before_save)
      end

      it "does not save the step to the form context" do
        expect(question).to receive(:before_save)
        expect(answer_store).not_to receive(:save_step)
        step.save_to_store(answer_store)
      end

      it "returns false" do
        expect(step.save_to_store(answer_store)).to be(false)
      end
    end
  end

  describe "#load_from_context" do
    it "loads the step from the form context" do
      allow(answer_store).to receive(:get_stored_answer).with(step).and_return({ name: "Test" })
      expect(question).to receive(:assign_attributes).with({ name: "Test" })
      step.load_from_store(answer_store)
    end
  end

  describe "#assign_question_attributes" do
    it "assigns attributes" do
      params = { name: "New Name" }
      expect(question).to receive(:assign_attributes).with(params)
      step.assign_question_attributes(params)
    end
  end

  describe "#params" do
    it "returns question attribute names with selection" do
      expect(step.params).to eq(["name", { selection: [] }])
    end
  end

  describe "#clear_errors" do
    it "clears errors on the question" do
      errors = instance_double(ActiveModel::Errors)
      allow(question).to receive(:errors).and_return(errors)
      expect(errors).to receive(:clear)
      step.clear_errors
    end
  end

  describe "#end_page?" do
    it "returns false" do
      expect(step.end_page?).to be(false)
    end
  end

  describe "#next_step_slug_after_routing" do
    let(:default_next_page) { second_step_id }
    let(:selection) { "Yes" }
    let(:question) { instance_double(Question::Selection, selection:) }
    let(:routing_conditions) { [] }
    let(:form_document_step) { build(:form_document_step, id: first_step_id, position: 1, next_page: default_next_page, routing_conditions:) }

    describe "basic routing" do
      context "without any routing conditions" do
        let(:selection) { "Any" }

        it "returns the next_step_slug when routing_conditions is empty" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end

      context "without conditions" do
        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end
    end

    describe "single condition routing" do
      context "with a matching condition" do
        let(:selection) { "Yes" }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "Yes", goto_page_id: third_step_id)] }

        it "returns the goto_page_id of the condition" do
          expect(step.next_step_slug_after_routing).to eq(third_step_id)
        end
      end

      context "with a matching none_of_the_above condition" do
        let(:selection) { "None of the above" }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "none_of_the_above", goto_page_id: third_step_id)] }

        it "returns the goto_page_id of the condition" do
          expect(step.next_step_slug_after_routing).to eq(third_step_id)
        end
      end

      context "with a non-matching condition" do
        let(:selection) { "No" }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "Yes", goto_page_id: third_step_id)] }

        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with a non-selection question and a default condition" do
        let(:question) { instance_double(Question::Text, :with_answer) }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "", goto_page_id: third_step_id)] }

        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(third_step_id)
        end
      end

      context "with a non-selection question and a match condition" do
        let(:question) { instance_double(Question::Text, :with_answer) }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "something", goto_page_id: third_step_id)] }

        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end
    end

    describe "skip_to_end routing" do
      context "with skip_to_end and no goto_page_id" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: nil, skip_to_end: true),
          ]
        end
        let(:selection) { "Yes" }

        it "returns the check your answers page slug" do
          expect(step.next_step_slug_after_routing).to eq(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)
        end
      end

      context "with skip_to_end and goto_page_id" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: fourth_step_id, skip_to_end: true),
          ]
        end
        let(:selection) { "Yes" }

        it "prioritizes goto_page_id over skip_to_end" do
          expect(step.next_step_slug_after_routing).to eq(fourth_step_id)
        end
      end
    end

    describe "with invalid states" do
      context "with multiple conditions and second matches" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "No", goto_page_id: first_step_id),
            OpenStruct.new(answer_value: "Yes", goto_page_id: second_step_id),
            OpenStruct.new(answer_value: "Maybe", goto_page_id: third_step_id),
          ]
        end
        let(:selection) { "Yes" }

        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with multiple conditions and second is default" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "No", goto_page_id: first_step_id),
            OpenStruct.new(answer_value: "Yes", goto_page_id: second_step_id),
            OpenStruct.new(answer_value: "", goto_page_id: third_step_id),
          ]
        end
        let(:selection) { "Something else" }

        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with multiple conditions but no matches" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: first_step_id),
            OpenStruct.new(answer_value: "No", goto_page_id: second_step_id),
            OpenStruct.new(answer_value: "Maybe", goto_page_id: third_step_id),
          ]
        end
        let(:selection) { "Something Else" }

        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with nil selection" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: first_step_id),
          ]
        end
        let(:selection) { nil }

        it "returns the next_step_slug" do
          expect(step.next_step_slug_after_routing).to eq(default_next_page)
        end
      end
    end
  end

  describe "#repeatable?" do
    it "returns false" do
      expect(step.repeatable?).to be false
    end
  end

  describe "#skipped?" do
    it "returns true if question is optional and show_answer is blank" do
      allow(question).to receive_messages(
        is_optional?: true,
        show_answer: "",
      )
      expect(step.skipped?).to be true
    end

    it "returns false if is_optional? is false" do
      allow(question).to receive_messages(
        is_optional?: false,
        show_answer: "",
      )
      expect(step.skipped?).to be false
    end

    it "returns false if show_answer is not blank" do
      allow(question).to receive_messages(
        is_optional?: true,
        show_answer: "something",
      )
      expect(step.skipped?).to be false
    end
  end

  shared_examples "delegates to question" do |method_name|
    it "delegates #{method_name} to question" do
      expect(question).to receive(method_name)
      step.send(method_name)
    end
  end

  describe "#valid?" do
    it_behaves_like "delegates to question", :valid?
  end

  describe "#show_answer" do
    it_behaves_like "delegates to question", :show_answer
  end

  describe "#show_answer_in_email" do
    it_behaves_like "delegates to question", :show_answer_in_email
  end

  describe "#show_answer_in_csv" do
    it_behaves_like "delegates to question", :show_answer_in_csv
  end

  describe "#question_text" do
    it_behaves_like "delegates to question", :question_text
  end

  describe "#hint_text" do
    it_behaves_like "delegates to question", :hint_text
  end

  describe "#answer_settings" do
    it_behaves_like "delegates to question", :answer_settings
  end

  describe "#show_answer_in_json" do
    let(:question) { build :first_and_last_name_question }
    let(:form_document_step) { build(:form_document_step, :with_name_settings, id: first_step_id) }
    let(:is_s3_submission) { false }
    let(:submission_reference) { "abc123" }

    it "returns a hash containing question and answer details" do
      expect(step.show_answer_in_json(submission_reference:, is_s3_submission:)).to eq({
        question_id: form_document_step.id,
        question_text: question.question_text,
        first_name: question.first_name,
        last_name: question.last_name,
        answer_text: question.show_answer,
      })
    end

    [true, false].each do |is_s3_submission|
      context "when is_s3_submission is #{is_s3_submission}" do
        it "passes is_s3_submission argument to the question" do
          expect(question).to receive(:show_answer_in_json).with(submission_reference:, is_s3_submission:).and_call_original
          step.show_answer_in_json(submission_reference:, is_s3_submission:)
        end
      end
    end
  end

  describe "#conditions_with_goto_errors" do
    let(:cannot_have_goto_page_before_routing_page_error) { OpenStruct.new(name: "cannot_have_goto_page_before_routing_page") }
    let(:goto_page_doesnt_exist_error) { OpenStruct.new(name: "goto_page_doesnt_exist") }
    let(:other_error) { OpenStruct.new(name: "some_other_error") }

    context "when there are no routing conditions" do
      let(:routing_conditions) { [] }
      let(:form_document_step) { build(:form_document_step, position: 1, routing_conditions: routing_conditions) }

      it "returns an empty array" do
        expect(step.conditions_with_goto_errors).to be_empty
      end
    end

    context "when routing conditions have no errors" do
      let(:condition) { OpenStruct.new(validation_errors: []) }
      let(:routing_conditions) { [condition] }
      let(:form_document_step) { build(:form_document_step, position: 1, routing_conditions: routing_conditions) }

      it "returns an empty array" do
        expect(step.conditions_with_goto_errors).to be_empty
      end
    end

    context "when routing conditions have relevant errors" do
      let(:condition) { OpenStruct.new(validation_errors: [cannot_have_goto_page_before_routing_page_error]) }
      let(:second_condition) { OpenStruct.new(validation_errors: [goto_page_doesnt_exist_error]) }
      let(:routing_conditions) { [condition, second_condition] }
      let(:form_document_step) { build(:form_document_step, position: 1, routing_conditions: routing_conditions) }

      it "returns conditions with specified errors" do
        expect(step.conditions_with_goto_errors).to contain_exactly(condition, second_condition)
      end
    end

    context "when routing conditions have irrelevant errors" do
      let(:condition) { OpenStruct.new(validation_errors: [other_error]) }
      let(:routing_conditions) { [condition] }
      let(:form_document_step) { build(:form_document_step, position: 1, routing_conditions: routing_conditions) }

      it "returns an empty array" do
        expect(step.conditions_with_goto_errors).to be_empty
      end
    end

    context "when routing conditions have mixed errors" do
      let(:condition_mixed) { OpenStruct.new(validation_errors: [cannot_have_goto_page_before_routing_page_error, other_error]) }
      let(:condition_other) { OpenStruct.new(validation_errors: [other_error]) }
      let(:condition_goto) { OpenStruct.new(validation_errors: [goto_page_doesnt_exist_error]) }
      let(:routing_conditions) { [condition_mixed, condition_other, condition_goto] }
      let(:form_document_step) { build(:form_document_step, position: 1, routing_conditions: routing_conditions) }

      it "returns only conditions with specified errors" do
        expect(step.conditions_with_goto_errors).to contain_exactly(condition_mixed, condition_goto)
      end
    end
  end

  describe "#has_exit_page_condition?" do
    it "returns false when no routing conditions" do
      expect(step.has_exit_page_condition?).to be false
    end

    it "returns false when first routing condition is not exit page" do
      form_document_step.routing_conditions = [OpenStruct.new(answer_value: "Yes", goto_page_id: third_step_id)]
      expect(step.has_exit_page_condition?).to be false
    end

    it "returns false when first routing condition contains markdown exit_page_markdown" do
      form_document_step.routing_conditions = [OpenStruct.new(exit_page_markdown: 12)]
      expect(step.has_exit_page_condition?).to be false
    end

    it "returns true when first routing condition contains string markdown exit_page_markdown" do
      form_document_step.routing_conditions = [OpenStruct.new(exit_page_markdown: "")]
      expect(step.has_exit_page_condition?).to be true
    end
  end

  describe "#exit_page_condition_matches?" do
    let(:selection) { "Yes" }
    let(:question) { instance_double(Question::Selection, selection:) }
    let(:routing_conditions) { [OpenStruct.new(answer_value: "Yes", exit_page_markdown: "string")] }
    let(:form_document_step) { build(:form_document_step, position: 1, routing_conditions:) }

    it "returns true when condition matches and condition is an exit page" do
      expect(step.exit_page_condition_matches?).to be true
    end

    it "when condition matches but not an exit page it returns false" do
      routing_conditions.first.exit_page_markdown = nil
      expect(step.exit_page_condition_matches?).to be false
    end

    context "when condition doesn't match" do
      let(:selection) { "No" }

      it "returns false" do
        expect(step.exit_page_condition_matches?).to be false
      end
    end
  end

  describe "#is_selection_with_none_of_the_above_answer?" do
    let(:question) { instance_double(Question::Selection) }

    it "trys to call show_none_of_the_above_question? on the question" do
      expect(question).to receive(:show_none_of_the_above_question?)
      step.is_selection_with_none_of_the_above_answer?
    end
  end
end
