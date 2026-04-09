require "rails_helper"

RSpec.describe Flow::Journey do
  subject(:journey) { described_class.new(answer_store:, form_document:) }

  let(:store) { {} }
  let(:step_factory) { Flow::StepFactory.new(form_document:) }

  let(:step_ids) { Array.new(4) { Faker::Alphanumeric.alphanumeric(number: 8) } }
  let(:first_step_id) { step_ids[0] }
  let(:second_step_id) { step_ids[1] }
  let(:third_step_id) { step_ids[2] }
  let(:fourth_step_id) { step_ids[3] }

  let(:form_id) { Faker::Alphanumeric.alphanumeric(number: 8) }
  let(:form_document) do
    build(:v2_form_document, :with_support,
          form_id:,
          start_page: first_step_id,
          steps: form_document_steps)
  end

  let(:first_step) do
    build :v2_selection_question_step,
          id: first_step_id,
          next_step_id: second_step_id,
          routing_conditions: [DataStruct.new(id: 1, routing_page_id: first_step_id, check_page_id: first_step_id, goto_page_id: third_step_id, answer_value: "Option 1", validation_errors:)]
  end

  let(:validation_errors) { [] }

  let(:second_step) { build :v2_question_step, :with_text_settings, id: second_step_id, next_step_id: third_step_id }
  let(:third_step) { build :v2_question_step, :with_text_settings, id: third_step_id, next_step_id: fourth_step_id }
  let(:fourth_step) { build :v2_question_step, :with_text_settings, id: fourth_step_id }

  let(:form_document_steps) { [first_step, second_step, third_step, fourth_step] }

  let(:first_step_in_journey) { step_factory.create_step(first_step.id).load_from_store(answer_store) }
  let(:second_step_in_journey) { step_factory.create_step(second_step.id).load_from_store(answer_store) }
  let(:third_step_in_journey) { step_factory.create_step(third_step.id).load_from_store(answer_store) }
  let(:fourth_step_in_journey) { step_factory.create_step(fourth_step_id).load_from_store(answer_store) }

  describe "#completed_steps" do
    context "when answers are loaded from the session" do
      let(:answer_store) { Store::SessionAnswerStore.new(store, form_id) }

      context "when no steps have been completed" do
        it "is empty" do
          expect(journey.completed_steps).to eq []
        end
      end

      context "when some of the steps have been completed" do
        let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" } } } } }

        it "includes only the steps that have been completed" do
          expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey].to_json
        end

        it "includes the answer data in the steps" do
          expect(journey.completed_steps.map(&:question)).to all be_answered
        end
      end

      context "when there is a gap in the steps that have been completed" do
        let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, third_step_id => { text: "More example text" } } } } }

        it "includes only the steps that have been completed before the gap" do
          expect(journey.completed_steps.to_json).to eq [first_step_in_journey].to_json
        end
      end

      context "when all steps have been completed" do
        let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" }, third_step_id => { text: "More example text" } } } } }

        it "includes all steps" do
          expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey, third_step_in_journey].to_json
        end

        it "includes the answer data in the question steps" do
          expect(journey.completed_steps.map(&:question)).to all be_answered
        end
      end

      context "when a question is optional" do
        let(:second_step) do
          build :v2_question_step, :with_text_settings,
                is_optional: true,
                id: second_step_id,
                next_step_id: third_step_id
        end

        context "and all questions have been answered" do
          let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" }, third_step_id => { text: "More example text" } } } } }

          it "includes all steps" do
            expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey, third_step_in_journey].to_json
          end
        end

        context "and the optional question has not been visited" do
          let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, third_step_id => { text: "More example text" } } } } }

          it "includes only steps that have been completed before the optional question" do
            expect(journey.completed_steps.to_json).to eq [first_step_in_journey].to_json
          end
        end

        context "and the optional question has a blank answer" do
          let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => { text: "" }, third_step_id => { text: "More example text" } } } } }

          it "includes all steps" do
            expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey, third_step_in_journey].to_json
          end
        end
      end

      context "when a step is repeatable" do
        let(:second_step) do
          build :v2_question_step, :with_text_settings,
                is_repeatable: true,
                id: second_step_id,
                next_step_id: third_step_id
        end

        context "when all steps have been completed" do
          let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => [{ text: "Example text" }], third_step_id => { text: "More example text" } } } } }

          it "includes all steps" do
            expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey, third_step_in_journey].to_json
          end

          it "includes the answer data in the question steps" do
            expect(journey.completed_steps.map(&:question)).to all be_answered
          end

          context "and the repeatable question has been answered more than once" do
            let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => [{ text: "Example text" }, { text: "Different example text" }], third_step_id => { text: "More example text" } } } } }

            it "includes all steps once each" do
              expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey, third_step_in_journey].to_json
            end
          end

          context "but the answer store does not have data in the format expected for the repeatable question" do
            let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" }, third_step_id => { text: "More example text" } } } } }

            it "includes only steps before the repeatable question" do
              expect(journey.completed_steps.to_json).to eq [first_step_in_journey].to_json
            end
          end
        end
      end

      context "when a form_document_step has a routing condition" do
        context "and the form_document_step answer matches the routing condition" do
          let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 1" }, third_step_id => { text: "More example text" } } } } }

          it "includes only steps in the matched route" do
            expect(journey.completed_steps.to_json).to eq [first_step_in_journey, third_step_in_journey].to_json
          end

          it "includes the answer data in the question steps" do
            expect(journey.completed_steps.map(&:question)).to all be_answered
          end

          context "when there are answers to questions not in the matched route" do
            let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 1" }, second_step_id => { text: "Example text" }, third_step_id => { text: "More example text" } } } } }

            it "includes only steps in the matched route" do
              expect(journey.completed_steps.to_json).to eq [first_step_in_journey, third_step_in_journey].to_json
            end
          end
        end
      end

      context "when the answer store has data that does not match the type expected by the question" do
        let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" }, third_step_id => { selection: "Option 1" } } } } }

        it "includes only steps before the answer with the wrong type" do
          expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey].to_json
        end

        it "includes the answer data in the question steps" do
          expect(journey.completed_steps.map(&:question)).to all be_answered
        end
      end

      context "when step has a cannot_have_goto_page_before_routing_page error" do
        let(:validation_errors) { [{ name: "cannot_have_goto_page_before_routing_page" }] }

        let(:first_step) do
          build :v2_question_step, :with_text_settings,
                id: first_step_id,
                next_step_id: second_step_id
        end

        let(:second_step) do
          build :v2_selection_question_step,
                id: second_step_id,
                next_step_id: third_step_id,
                routing_conditions: [DataStruct.new(id: 1, routing_page_id: second_step_id, check_page_id: second_step_id, goto_page_id: first_step_id, answer_value: "Option 1", validation_errors:)],
                is_optional: false
        end

        let(:store) { { answers: { form_id.to_s => { first_step_id => { text: "Example text" }, second_step_id => { selection: second_step.routing_conditions.first.answer_value }, third_step_id => { text: "More example text" } } } } }

        it "stops generating the completed_steps when it reaches the question with the error" do
          expect(journey.completed_steps.to_json).to eq [first_step_in_journey].to_json
        end
      end

      context "when there are multiple files with the same name" do
        let(:first_step) { build(:v2_question_step, answer_type: "file", id: first_step_id, next_step_id: second_step_id) }
        let(:second_step) { build(:v2_question_step, answer_type: "file", id: second_step_id, next_step_id: third_step_id) }
        let(:third_step) { build(:v2_question_step, answer_type: "file", id: third_step_id, next_step_id: fourth_step_id) }
        let(:fourth_step) { build(:v2_question_step, answer_type: "file", id: fourth_step_id) }
        let(:form_document_steps) { [first_step, second_step, third_step, fourth_step] }
        let(:store) do
          {
            answers: {
              form_id.to_s =>
                {
                  first_step_id => { uploaded_file_key: "key1", original_filename: "file1", filename_suffix: "" },
                  second_step_id => { uploaded_file_key: "key2", original_filename: "a different filename", filename_suffix: "" },
                  third_step_id => { uploaded_file_key: "key3", original_filename: "file1", filename_suffix: "" },
                  fourth_step_id => { uploaded_file_key: "key4", original_filename: "file1", filename_suffix: "" },
                },
            },
          }
        end

        it "does not add a numerical suffix to the first instance of a filename" do
          expect(journey.all_steps[0].question.filename_suffix).to eq("")
          expect(journey.all_steps[1].question.filename_suffix).to eq("")
        end

        it "adds a numerical suffix to any files with duplicate filenames" do
          expect(journey.all_steps[2].question.filename_suffix).to eq("_1")
          expect(journey.all_steps[3].question.filename_suffix).to eq("_2")
        end
      end

      context "when there are multiple files with different names that are the same after truncation" do
        let(:first_step) { build(:v2_question_step, answer_type: "file", id: first_step_id, next_step_id: second_step_id) }
        let(:second_step) { build(:v2_question_step, answer_type: "file", id: second_step_id, next_step_id: third_step_id) }
        let(:third_step) { build(:v2_question_step, answer_type: "file", id: third_step_id, next_step_id: fourth_step_id) }
        let(:fourth_step) { build(:v2_question_step, answer_type: "file", id: fourth_step_id) }
        let(:form_document_steps) { [first_step, second_step, third_step, fourth_step] }
        let(:store) do
          {
            answers: {
              form_id.to_s =>
                {
                  first_step_id => { uploaded_file_key: "key1", original_filename: "this_is_an_incredibly_long_filename_that_will_surely_have_to_be_truncated_somewhere_near_the_end_version_one", filename_suffix: "" },
                  second_step_id => { uploaded_file_key: "key2", original_filename: "a different filename", filename_suffix: "" },
                  third_step_id => { uploaded_file_key: "key3", original_filename: "this_is_an_incredibly_long_filename_that_will_surely_have_to_be_truncated_somewhere_near_the_end_version_two", filename_suffix: "" },
                  fourth_step_id => { uploaded_file_key: "key4", original_filename: "this_is_an_incredibly_long_filename_that_will_surely_have_to_be_truncated_somewhere_near_the_end_version_three", filename_suffix: "" },
                },
            },
          }
        end

        it "does not add a numerical suffix to the first instance of a filename" do
          expect(journey.all_steps[0].question.filename_suffix).to eq("")
          expect(journey.all_steps[1].question.filename_suffix).to eq("")
        end

        it "adds a numerical suffix to any files which would have duplicate filenames after truncation" do
          expect(journey.all_steps[2].question.filename_suffix).to eq("_1")
          expect(journey.all_steps[3].question.filename_suffix).to eq("_2")
        end
      end
    end

    context "when answers are loaded from the database" do
      let(:answer_store) { Store::DatabaseAnswerStore.new(answers) }

      context "when some of the steps have been completed" do
        let(:answers) { { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" } } }

        it "includes only the steps that have been completed" do
          expect(journey.completed_steps.to_json).to eq [first_step_in_journey, second_step_in_journey].to_json
        end

        it "includes the answer data in the question steps" do
          expect(journey.completed_steps.map(&:question)).to all be_answered
        end
      end
    end
  end

  describe "#all_steps" do
    context "when answers are loaded from the session" do
      let(:answer_store) { Store::SessionAnswerStore.new(store, form_id) }

      context "when some questions have not been answered" do
        let(:store) { { answers: { form_id.to_s => { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" } } } } }

        it "creates steps for the unanswered questions" do
          expect(journey.all_steps.length).to eq(4)
          expect(journey.all_steps.to_json).to eq [first_step_in_journey,
                                                   second_step_in_journey,
                                                   third_step_in_journey,
                                                   fourth_step_in_journey].to_json
        end
      end
    end

    context "when answers are loaded from the database" do
      let(:answer_store) { Store::DatabaseAnswerStore.new(answers) }

      context "when some questions have not been answered" do
        let(:answers) { { first_step_id => { selection: "Option 2" }, second_step_id => { text: "Example text" } } }

        it "creates steps for the unanswered questions" do
          expect(journey.all_steps.length).to eq(4)
          expect(journey.all_steps.to_json).to eq [first_step_in_journey,
                                                   second_step_in_journey,
                                                   third_step_in_journey,
                                                   fourth_step_in_journey].to_json
        end
      end
    end
  end

  describe "#step_by_id" do
    let(:answer_store) { Store::SessionAnswerStore.new(store, form_id) }

    it "returns the step with the matching ID" do
      step = journey.step_by_id(second_step_id)
      expect(step.to_json).to eq second_step_in_journey.to_json
    end

    it "raises an error if no step is found matching the ID" do
      expect { journey.step_by_id("non-existent-id") }.to raise_error(Flow::Journey::StepNotFoundError)
    end
  end

  describe "#completed_file_upload_questions" do
    let(:first_step) { build(:v2_question_step, answer_type: "file", id: first_step_id, next_step_id: second_step_id) }
    let(:second_step) { build(:v2_question_step, answer_type: "file", id: second_step_id, next_step_id: third_step_id) }
    let(:third_step) { build(:v2_question_step, answer_type: "file", id: third_step_id, next_step_id: fourth_step_id) }
    let(:fourth_step) { build(:v2_question_step, :with_text_settings, id: fourth_step_id) }
    let(:form_document_steps) { [first_step, second_step, third_step, fourth_step] }

    let(:answer_store) { Store::SessionAnswerStore.new(store, form_id) }
    let(:store) do
      {
        answers: {
          form_id.to_s =>
            {
              first_step_id => { uploaded_file_key: "key1", original_filename: "file1" },
              second_step_id => { original_filename: "" },
              third_step_id => { uploaded_file_key: "key2", original_filename: "file2" },
              fourth_step_id => { text: "Example text" },
            },
        },
      }
    end

    it "returns the answered file upload questions" do
      completed_file_upload_questions = journey.completed_file_upload_questions
      expect(completed_file_upload_questions.length).to eq 2
      expect(completed_file_upload_questions.first.uploaded_file_key).to eq "key1"
      expect(completed_file_upload_questions.second.uploaded_file_key).to eq "key2"
    end
  end

  describe "journey navigation methods" do
    let(:answer_store) { Store::SessionAnswerStore.new(store, form_id) }

    context "when no questions have been answered" do
      it "can visit the first step" do
        expect(journey.can_visit?(first_step_id)).to be true
      end

      it "cannot visit the second step" do
        expect(journey.can_visit?(second_step_id)).to be false
      end

      it "cannot visit the check your answers step" do
        expect(journey.can_visit?(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)).to be false
      end

      it "has no previous step" do
        expect(journey.previous_step(first_step_id)).to be_nil
      end

      it "has the next step slug as the first step" do
        expect(journey.next_step_slug).to eq first_step_id
      end
    end

    context "when some of the questions has been answered" do
      let(:store) do
        {
          answers: {
            form_id.to_s => { first_step_id => { selection: "Option 2" },
                              second_step_id => { text: "Example text" } },
          },
        }
      end

      it "can visit the completed steps" do
        expect(journey.can_visit?(first_step_id)).to be true
        expect(journey.can_visit?(second_step_id)).to be true
      end

      it "can visit the next incomplete step" do
        expect(journey.can_visit?(third_step_id)).to be true
      end

      it "cannot visit steps after the next incomplete step" do
        expect(journey.can_visit?(fourth_step_id)).to be false
      end

      it "cannot visit the check your answers step" do
        expect(journey.can_visit?(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)).to be false
      end

      it "has the correct previous steps for the completed steps" do
        expect(journey.previous_step(first_step_id)).to be_nil
        expect(journey.previous_step(second_step_id).id).to eq first_step_id
        expect(journey.previous_step(third_step_id).id).to eq second_step_id
      end

      it "has the next step slug as the next incomplete step" do
        expect(journey.next_step_slug).to eq third_step_id
      end
    end

    context "when all questions have been answered" do
      let(:store) do
        {
          answers: {
            form_id.to_s => { first_step_id => { selection: "Option 2" },
                              second_step_id => { text: "Example text" },
                              third_step_id => { text: "More example text" },
                              fourth_step_id => { text: "Even more example text" } },
          },
        }
      end

      it "can visit all steps" do
        expect(journey.can_visit?(first_step_id)).to be true
        expect(journey.can_visit?(second_step_id)).to be true
        expect(journey.can_visit?(third_step_id)).to be true
        expect(journey.can_visit?(fourth_step_id)).to be true
      end

      it "can visit the check your answers step" do
        expect(journey.can_visit?(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG)).to be true
      end

      it "has the next step slug as the check your answers step" do
        expect(journey.next_step_slug).to eq CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG
      end
    end
  end
end
