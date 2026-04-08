require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe Flow::Context do
  before do
    ActiveResource::HttpMock.disable_net_connection!
  end

  let(:steps) do
    [
      build(:v2_question_step, :with_text_settings, id: 1, next_step_id: 2),
      build(:v2_question_step, :with_text_settings, id: 2),
    ]
  end

  let(:form) do
    build(:form, :with_support,
          id: 2,
          start_page: 1,
          privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
          what_happens_next_markdown: "Good things come to those that wait",
          declaration_text: "agree to the declaration",
          steps:)
  end

  [
    ["no input", { answers: [], request_step: 1 }, { next_step_slug: "2", start_id: 1, next_incomplete_page_id: "1", current_step_id: "1", previous_step_id: nil }],
    ["first question complete, request second step", { answers: [{ text: "q1 answer" }], request_step: 2 }, { next_step_slug: CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG, start_id: 1, previous_step_id: "1", next_incomplete_page_id: "2", current_step_id: "2" }],
    ["first question complete, request first step", { answers: [{ text: "q1 answer" }], request_step: 1 }, { next_step_slug: "2", start_id: 1, previous_step_id: nil, next_incomplete_page_id: "2", current_step_id: "1" }],
    ["all questions complete, request second step", { answers: [{ text: "q1 answer" }, { text: "q2 answer" }], request_step: 2 }, { next_step_slug: CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG, start_id: 1, previous_step_id: "1", next_incomplete_page_id: CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG, current_step_id: "2" }],
  ].each do |variation, input, expected_output|
    context "with #{variation}" do
      before do
        store = {}
        @context = described_class.new(form:, store:)

        current_step = @context.find_or_create(@context.next_step_slug)

        input[:answers].each do |answer|
          current_step.assign_question_attributes(answer)
          @context.save_step(current_step)
          next_step_slug = current_step.next_step_slug
          break if next_step_slug.nil?

          current_step = @context.find_or_create(next_step_slug)
        end
        @context = described_class.new(form:, store:)
        @step = @context.find_or_create(input[:request_step])
      end

      it "can visit the start form_document_step" do
        expect(@context.can_visit?("1")).to be true
      end

      it "has the correct previous step" do
        expect(@context.previous_step(@step.id)&.id).to eq(expected_output[:previous_step_id])
      end

      it "has the correct next incomplete step" do
        expect(@context.next_step_slug).to eq(expected_output[:next_incomplete_page_id])
      end

      describe "step" do
        it "has the right id" do
          expect(@step.id).to eq(expected_output[:current_step_id])
        end

        it "has the correct next_step_slug" do
          expect(@step.next_step_slug).to eq(expected_output[:next_step_slug])
        end
      end
    end
  end

  context "with a step which changes question type mid-journey" do
    it "does not throw an error if the question type changes when an answer has already been submitted" do
      store = {}

      # submit an answer
      context1 = described_class.new(form:, store:)
      current_step = context1.find_or_create("1")
      current_step.assign_question_attributes({ text: "This is a text answer" })
      context1.save_step(current_step)

      # change the step's answer_type to another value
      form.form_document_steps[0].data.answer_type = "number"

      # build another context with the previous answers
      context2 = described_class.new(form:, store:)
      expect(context2.find_or_create("1").show_answer).to eq("")
    end
  end

  describe "submission details" do
    let(:context) { described_class.new(form:, store: {}) }
    let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
    let(:requested_email_confirmation) { true }

    context "when submission details have been stored" do
      before do
        context.save_submission_details(reference, requested_email_confirmation)
      end

      it "the reference number can be retrieved" do
        expect(context.get_submission_reference).to eq(reference)
      end

      it "the requested_email_confirmation value can be retrieved" do
        expect(context.requested_email_confirmation?).to eq(requested_email_confirmation)
      end

      it "can be cleared" do
        context.save_submission_details(reference, requested_email_confirmation)
        context.clear_submission_details

        expect(context.get_submission_reference).to be_nil
        expect(context.requested_email_confirmation?).to be_nil
      end
    end
  end

  describe "#save_step" do
    let(:answer_store) { instance_double(Store::SessionAnswerStore) }
    let(:step) { instance_double(Step) }
    let(:context_instance) { described_class.new(form:, store: {}) }

    before do
      allow(context_instance).to receive(:answer_store).and_return(answer_store)
    end

    context "when the step is valid" do
      before do
        allow(step).to receive_messages(valid?: true, save_to_store: true)
        allow(answer_store).to receive(:add_locale)
      end

      it "saves the step to the answer store" do
        expect(step).to receive(:save_to_store).with(answer_store)
        context_instance.save_step(step)
      end

      it "adds the locale to the answer store" do
        expect(answer_store).to receive(:add_locale).with(:en)
        context_instance.save_step(step)
      end

      it "passes the context to the valid? method if provided" do
        custom_context = { some: "context" }
        expect(step).to receive(:valid?).with(custom_context)
        context_instance.save_step(step, context: custom_context)
      end

      it "uses the provided locale" do
        custom_locale = :cy
        expect(answer_store).to receive(:add_locale).with(custom_locale)
        context_instance.save_step(step, locale: custom_locale)
      end

      it "returns truthy" do
        expect(context_instance.save_step(step)).to be_truthy
      end
    end

    context "when the step is invalid" do
      before do
        allow(step).to receive(:valid?).and_return(false)
      end

      it "does not save the step to the answer store" do
        expect(step).not_to receive(:save_to_store)
        context_instance.save_step(step)
      end

      it "does not add the locale to the answer store" do
        expect(answer_store).not_to receive(:add_locale)
        context_instance.save_step(step)
      end

      it "returns false" do
        expect(context_instance.save_step(step)).to be false
      end
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
