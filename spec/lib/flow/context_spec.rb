require "rails_helper"

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
          start_page: 1,
          privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
          what_happens_next_markdown: "Good things come to those that wait",
          declaration_text: "agree to the declaration",
          steps:)
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
