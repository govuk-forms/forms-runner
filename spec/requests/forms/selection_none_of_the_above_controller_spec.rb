require "rails_helper"

RSpec.describe Forms::SelectionNoneOfTheAboveController, type: :request do
  let(:mode) { "form" }
  let(:req_headers) { { "Accept" => "application/json" } }

  let(:step_slug) { selection_question_step.id }

  let(:text_question_step) do
    build :v2_question_step, :with_text_settings, id: 1, next_step_id: selection_question_step.id
  end

  let(:selection_options) { Array.new(31).map { |i| { name: "Option #{i}", value: "Option #{i}" } } }
  let(:none_of_the_above_question_text) { "Give another answer" }
  let(:selection_question_step) do
    build(:v2_selection_question_step,
          :with_none_of_the_above_question,
          id: 2,
          next_step_id: final_step.id,
          selection_options:,
          none_of_the_above_question_text:)
  end
  let(:final_step) { build(:v2_question_step, id: 3) }

  let(:steps_data) { [text_question_step, selection_question_step, final_step] }

  let(:form_data) do
    build(:v2_form_document, :with_support,
          form_id: 2,
          start_page: text_question_step.id,
          privacy_policy_url: "http://www.example.gov.uk/privacy_policy",
          what_happens_next_markdown: "Good things come to those that wait",
          declaration_text: "agree to the declaration",
          steps: steps_data)
  end

  let(:store) do
    {
      answers: {
        form_data.form_id.to_s => {
          text_question_step.id.to_s => {
            "text" => "answer",
          },
        },
      },
    }
  end

  let(:changing_existing_answer) { false }

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/2/live", req_headers, form_data.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      context_spy = original_method.call(form: args[0][:form], form_document: args[0][:form_document], store:)
      context_spy
    end
  end

  describe "#show" do
    before do
      get selection_none_of_the_above_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:, changing_existing_answer:)
    end

    context "when the previous step is not answered" do
      let(:store) { { answers: {} } }

      it "redirects to the previous step" do
        expect(response).to redirect_to(form_step_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug: text_question_step.id))
      end
    end

    context "when the step is not a selection question" do
      let(:step_slug) { text_question_step.id }

      it "redirects to the step route" do
        expect(response).to redirect_to(form_step_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:))
      end
    end

    context "when the step is a selection question" do
      context "when the selection question does not have a none of the above question" do
        let(:selection_question_step) do
          build(:v2_selection_question_step,
                selection_options:,
                id: 2,
                next_step_id: final_step.id)
        end

        it "redirects to the step route" do
          expect(response).to redirect_to(form_step_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:))
        end
      end

      context "when the selection question has a none of the above question" do
        context "when the selection question uses an autocomplete component" do
          it "returns a 200" do
            expect(response).to have_http_status(:ok)
          end

          it "renders the show template" do
            expect(response).to render_template("forms/selection_none_of_the_above/show")
          end

          it "includes the question text" do
            expect(response.body).to include(none_of_the_above_question_text)
          end

          it "assigns a back link" do
            expect(assigns(:back_link)).to eq(form_step_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:))
          end

          it "assigns an question edit link" do
            expect(assigns(:question_edit_link)).to eq("#{Settings.forms_admin.base_url}/forms/#{form_data.form_id}/pages-by-external-id/#{step_slug}/edit-question")
          end

          context "when changing an existing answer" do
            let(:changing_existing_answer) { true }

            it "assigns a back link to the check your answers page" do
              expect(assigns(:back_link)).to eq(check_your_answers_path(form_id: form_data.form_id))
            end
          end
        end

        context "when the selection question does not use an autocomplete component" do
          let(:selection_options) { [{ name: "Option 1", value: "Option 1" }, { name: "Option 2", value: "Option 2" }] }

          it "redirects to the step route" do
            expect(response).to redirect_to(form_step_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:))
          end
        end
      end
    end
  end

  describe "#save" do
    let(:post_path) { save_selection_none_of_the_above_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:) }

    context "when the answer is valid" do
      before do
        post post_path, params: { question: { none_of_the_above_answer: "Custom answer" } }
      end

      it "redirects to the next page" do
        expect(response).to redirect_to(form_step_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug: final_step.id))
      end
    end

    context "when save fails" do
      before do
        post post_path, params: { question: { none_of_the_above_answer: nil } }
      end

      it "renders the show template with 422" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template("forms/selection_none_of_the_above/show")
      end

      it "assigns a back link" do
        expect(assigns(:back_link)).to eq(form_step_path(mode:, form_id: form_data.form_id, form_slug: form_data.form_slug, step_slug:))
      end

      it "assigns an question edit link" do
        expect(assigns(:question_edit_link)).to eq("#{Settings.forms_admin.base_url}/forms/#{form_data.form_id}/pages-by-external-id/#{step_slug}/edit-question")
      end
    end

    context "when the answer is invalid" do
      before do
        post post_path, params: { question: { none_of_the_above_answer: nil } }
      end

      it "renders the show template with a 422 status" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template("forms/selection_none_of_the_above/show")
      end
    end
  end
end
