require "rails_helper"

RSpec.describe Forms::ContinueSavedFormController, type: :request do
  let(:form) do
    build(:form_document, :with_support, form_id: 2, start_page: 1, steps:, save_and_return: "enabled")
  end

  let(:steps) do
    [
      build(:question_step, :with_text_settings, id: 1, next_step_id: 2),
      build(:question_step, :with_text_settings, id: 2),
    ]
  end

  let(:req_headers) { { "Accept" => "application/json" } }
  let(:api_url_suffix) { "/draft" }
  let(:mode) { "preview-draft" }

  let(:auth_session) { {} }

  let(:store) { auth_session.with_indifferent_access }

  before do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}#{api_url_suffix}", req_headers, form.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      original_method.call(form: args[0][:form], form_document: args[0][:form_document], store:)
    end
    allow(AuthService).to receive(:new).and_wrap_original do |original_method, *_args|
      original_method.call(store)
    end
  end

  describe "GET #new" do
    context "when the user is signed in to GOV.UK One Login" do
      let(:auth_session) do
        {
          auth: {
            sub: "user-sub-123",
            email: "test@example.com",
            token: "a-token",
            authenticated_at: Time.current.to_i,
          },
        }
      end

      context "and they have saved progress for the form" do
        before do
          IncompleteSubmission.create!(user_id: "user-sub-123", form_id: form.form_id, answers: { "1" => { "text" => "a saved answer" } })

          get continue_saved_form_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
        end

        it "redirects to the first question" do
          expect(response).to redirect_to(form_step_path(mode:, form_id: form.form_id, form_slug: form.form_slug, step_slug: 1))
        end
      end

      context "and they have no saved progress for the form" do
        before do
          get continue_saved_form_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
        end

        it "shows the page saying their saved form could not be found" do
          expect(response).to have_http_status(:not_found)
          expect(response).to render_template(:not_found)
          expect(response.body).to include(I18n.t("forms.continue_saved_form.not_found.title"))
        end

        it "links to start a new form" do
          expect(response.body).to include(form_step_path(mode:, form_id: form.form_id, form_slug: form.form_slug, step_slug: 1))
        end
      end
    end
  end
end
