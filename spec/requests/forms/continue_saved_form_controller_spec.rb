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
    context "when the user is not signed in to GOV.UK One Login" do
      before do
        get continue_saved_form_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
      end

      it "renders the One Login sign-in interstitial" do
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:new)
        expect(response.body).to include(I18n.t("forms.continue_saved_form.new.title"))
      end

      it "stores the continue saved form return params for returning from One Login on the session" do
        expect(store["return_from_one_login"]).to eq({
          "last_form_id" => form.form_id,
          "last_form_slug" => form.form_slug,
          "last_mode" => mode.to_s,
          "last_locale" => nil,
          "return_to" => "continue_saved_form",
        })
      end
    end

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

  describe "GET #signed_in" do
    def get_signed_in
      get continue_saved_form_signed_in_path(mode:, form_id: form.form_id, form_slug: form.form_slug)
    end

    let(:signed_in_session) do
      {
        auth: {
          sub: "user-sub-123",
          email: "test@example.com",
          token: "a-token",
          authenticated_at: Time.current.to_i,
        },
      }
    end

    context "when the user is not signed in to GOV.UK One Login" do
      before { get_signed_in }

      it "redirects to the sign-in interstitial" do
        expect(response).to redirect_to(continue_saved_form_path(form.form_id, form.form_slug, mode:))
      end
    end

    context "when the user is signed in but did not start the continue saved form journey" do
      let(:auth_session) { signed_in_session }

      before { get_signed_in }

      it "redirects to the sign-in interstitial" do
        expect(response).to redirect_to(continue_saved_form_path(form.form_id, form.form_slug, mode:))
      end
    end

    context "when the user is signed in after starting the continue saved form journey" do
      let(:auth_session) { signed_in_session.merge(return_from_one_login: { return_to: "continue_saved_form" }) }

      context "and they have saved progress for the form" do
        before do
          IncompleteSubmission.create!(user_id: "user-sub-123", form_id: form.form_id, answers: { "1" => { "text" => "a saved answer" } })

          get_signed_in
        end

        it "redirects to the first question" do
          expect(response).to redirect_to(form_step_path(mode:, form_id: form.form_id, form_slug: form.form_slug, step_slug: 1))
        end

        it "loads the saved answers into the session" do
          expect(store.dig(:answers, form.form_id.to_s)).to eq({ "1" => { "text" => "a saved answer" } })
        end

        it "clears the return from One Login params" do
          expect(store).not_to have_key(:return_from_one_login)
        end
      end

      context "and they have no saved progress for the form" do
        before { get_signed_in }

        it "shows the page saying their saved form could not be found" do
          expect(response).to have_http_status(:not_found)
          expect(response).to render_template(:not_found)
        end
      end
    end
  end
end
