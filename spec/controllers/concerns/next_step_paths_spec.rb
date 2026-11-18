require "rails_helper"

RSpec.describe NextStepPaths do
  subject(:controller) { controller_class.new(form:) }

  let(:controller_class) do
    Class.new do
      include Rails.application.routes.url_helpers
      include NextStepPaths

      public :next_step_path

      attr_reader :current_context

      def initialize(form:)
        @form = form
        @current_context = OpenStruct.new(form:)
      end

      def default_url_options
        { mode: "form", locale: nil }
      end
    end
  end

  let(:form) { instance_double(Form, id: 1, form_slug: "form-slug", copy_of_answers_enabled?: copy_of_answers_enabled) }
  let(:copy_of_answers_enabled) { false }

  let(:step) { instance_double(Step, id: "1", repeatable?: repeatable, skipped?: skipped, next_step_slug_after_routing:) }
  let(:repeatable) { false }
  let(:skipped) { false }
  let(:next_step_slug_after_routing) { "2" }

  describe "#next_step_path" do
    it "returns the path to the next step in the form" do
      expect(controller.next_step_path(step)).to eq "/form/1/form-slug/2"
    end

    context "when routing sends the user to a different step" do
      let(:next_step_slug_after_routing) { "5" }

      it "returns the path to the step routed to" do
        expect(controller.next_step_path(step)).to eq "/form/1/form-slug/5"
      end
    end

    context "when the step is repeatable" do
      let(:repeatable) { true }

      it "returns the path to the add another answer page for the step" do
        expect(controller.next_step_path(step)).to eq "/form/1/form-slug/1/add-another-answer"
      end

      context "and the step was skipped" do
        let(:skipped) { true }

        it "returns the path to the next step in the form" do
          expect(controller.next_step_path(step)).to eq "/form/1/form-slug/2"
        end
      end
    end

    context "when the next step is check your answers" do
      let(:next_step_slug_after_routing) { CheckYourAnswersStep::CHECK_YOUR_ANSWERS_STEP_SLUG }

      it "returns the path to the check your answers page" do
        expect(controller.next_step_path(step)).to eq "/form/1/form-slug/check-your-answers"
      end

      context "and copy of answers is enabled on the form" do
        let(:copy_of_answers_enabled) { true }

        it "returns the path to the copy of answers page" do
          expect(controller.next_step_path(step)).to eq "/form/1/form-slug/copy-of-answers"
        end
      end
    end
  end
end
