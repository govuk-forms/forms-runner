require "rails_helper"

RSpec.describe Forms::RemoveAnswerController, type: :request do
  let(:form) do
    build(:v2_form_document, :with_support, form_id: 2, start_page: 1, steps:)
  end

  let(:steps) { [first_step_in_form, second_step_in_form] }
  let(:is_optional) { false }
  let(:remove) { "yes" }

  let(:first_step_in_form) do
    build :v2_question_step,
          :with_text_settings,
          :with_repeatable,
          id: 1,
          next_step_id: 2,
          is_optional:
  end

  let(:second_step_in_form) do
    build :v2_question_step, :with_text_settings, id: 2
  end

  let(:req_headers) { { "Accept" => "application/json" } }

  let(:api_url_suffix) { "/draft" }

  let(:stored_answers) do
    [{ text: "answer 1" }, { text: "answer 2" }]
  end

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}#{api_url_suffix}", req_headers, form.to_json, 200
    end

    answer_store = instance_double(Store::SessionAnswerStore)
    allow(Store::SessionAnswerStore).to receive(:new).and_return(answer_store)
    allow(answer_store).to receive(:clear_stored_answer)
    allow(answer_store).to receive(:get_stored_answer).and_return(stored_answers)
    allow(answer_store).to receive(:save_step)
    allow(answer_store).to receive(:add_locale)
  end

  describe "GET #show" do
    before do
      get form_remove_answer_path(mode: "preview-draft", form_id: form.form_id, form_slug: form.form_slug, step_slug: first_step_in_form.id, answer_index: 1)
    end

    it "renders the show template" do
      expect(response).to render_template(:show)
    end

    it "initializes @remove_input" do
      expect(assigns(:remove_input)).to be_a(RemoveInput)
    end
  end

  describe "DELETE #delete" do
    let(:params) { { remove_input: { remove: } } }

    before do
      delete form_remove_answer_path(mode: "preview-draft", form_id: form.form_id, form_slug: form.form_slug, step_slug: first_step_in_form.id, answer_index: 1), params:
    end

    context "with valid params" do
      it "redirects to add another answer" do
        expect(response).to redirect_to(add_another_answer_path(mode: "preview-draft", form_id: form.form_id, form_slug: form.form_slug, step_slug: first_step_in_form.id))
      end

      context "when not removing answer" do
        let(:remove) { "no" }

        it "redirects to add another answer" do
          expect(response).to redirect_to(add_another_answer_path(mode: "preview-draft", form_id: form.form_id, form_slug: form.form_slug, step_slug: first_step_in_form.id))
        end
      end
    end

    context "with invalid params" do
      let(:remove) { "invalid" }

      it "renders the show template" do
        expect(response).to render_template(:show)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when removing an answer for an optional question with no remaining answers" do
      let(:stored_answers) { [{ text: "answer 1" }] }
      let(:is_optional) { true }

      it "redirects to the question page" do
        expect(response).to redirect_to(form_step_path(mode: "preview-draft", form_id: form.form_id, form_slug: form.form_slug, step_slug: first_step_in_form.id))
      end
    end
  end
end
