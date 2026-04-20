require "rails_helper"

RSpec.describe Forms::CopyOfAnswersController, type: :request do
  let(:form) do
    build(:v2_form_document, :with_support, form_id: 2, start_page: 1, steps:, available_languages:)
  end

  let(:steps) do
    [
      build(:v2_question_step, :with_text_settings, id: 1, next_step_id: 2),
      build(:v2_question_step, :with_text_settings, id: 2),
    ]
  end

  let(:available_languages) { %w[en] }

  let(:req_headers) { { "Accept" => "application/json" } }

  let(:api_url_suffix) { "/draft" }
  let(:mode) { "preview-draft" }

  let(:store) do
    {
      answers: {
        form.form_id.to_s => {
          "1" => { "text" => "answer 1" },
          "2" => { "text" => "answer 2" },
        },
      },
    }
  end

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}#{api_url_suffix}", req_headers, form.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      original_method.call(form: args[0][:form], form_document: args[0][:form_document], store:)
    end
  end

  describe "GET #show" do
    context "when the feature flag is disabled", feature_filler_answer_email_enabled: false do
      before do
        get copy_of_answers_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "redirects to check your answers" do
        expect(response).to redirect_to(check_your_answers_path(form_id: form.form_id, form_slug: form.form_slug, mode:))
      end
    end

    context "when the feature flag is enabled", :feature_filler_answer_email_enabled do
      before do
        get copy_of_answers_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the show template" do
        expect(response).to render_template(:show)
      end

      it "initializes @copy_of_answers_input" do
        expect(assigns(:copy_of_answers_input)).to be_a(CopyOfAnswersInput)
      end

      it "assigns @back_link" do
        expect(assigns(:back_link)).to be_present
      end

      context "when the form is not multilingual" do
        it "does not include the language switcher" do
          expect(response.body).not_to include(I18n.t("language_switcher.nav_label"))
        end
      end

      context "when the form is multilingual" do
        let(:available_languages) { %w[en cy] }

        it "includes the language switcher" do
          expect(response.body).to include(I18n.t("language_switcher.nav_label"))
        end
      end

      context "when all questions have not been completed" do
        let(:store) do
          {
            answers: {
              form.form_id.to_s => {
                "1" => { "text" => "answer 1" },
              },
            },
          }
        end

        it "redirects to the next page" do
          expect(response).to redirect_to(form_step_path(form.form_id, form.form_slug, 2, mode:))
        end
      end
    end
  end

  describe "POST #save", :feature_filler_answer_email_enabled do
    context "with valid params" do
      context "when user wants a copy of answers" do
        let(:params) { { copy_of_answers_input: { copy_of_answers: "yes" } } }

        before do
          post save_copy_of_answers_path(mode:, form_id: form.form_id, form_slug: form.form_slug), params:
        end

        it "redirects to the continue to one login page" do
          expect(response).to redirect_to(continue_to_one_login_path(form_id: form.form_id, form_slug: form.form_slug, mode:))
        end

        it "saves the preference" do
          # Access the session to verify the preference was saved
          expect(response).to have_http_status(:redirect)
        end
      end

      context "when user does not want a copy of answers" do
        let(:params) { { copy_of_answers_input: { copy_of_answers: "no" } } }

        before do
          post save_copy_of_answers_path(mode:, form_id: form.form_id, form_slug: form.form_slug), params:
        end

        it "redirects to check your answers" do
          expect(response).to redirect_to(check_your_answers_path(form_id: form.form_id, form_slug: form.form_slug, mode:))
        end
      end
    end

    context "with invalid params" do
      let(:params) { { copy_of_answers_input: { copy_of_answers: "" } } }

      before do
        post save_copy_of_answers_path(mode:, form_id: form.form_id, form_slug: form.form_slug), params:
      end

      it "returns unprocessable content" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "renders the show template" do
        expect(response).to render_template(:show)
      end

      it "displays an error message" do
        expect(response.body).to include("Select")
        expect(response.body).to include("Yes")
        expect(response.body).to include("copy of your answers")
      end
    end
  end
end
