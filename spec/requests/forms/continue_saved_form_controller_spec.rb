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
          create(:incomplete_submission, user_id: "user-sub-123", form_id: form.form_id, answers: { "1" => { "text" => "a saved answer" } }, mode:)

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

        it "asks whether the user wants to start a new form" do
          expect(response.body).to include(I18n.t("helpers.legend.start_new_form_input.start_new_form"))
        end

        it "shows the email address the user is signed in with" do
          expect(response.body).to include("<strong>test@example.com</strong>")
        end
      end
    end
  end

  describe "POST #submit_not_found" do
    def post_submit_not_found
      post submit_continue_saved_form_not_found_path(mode:, form_id: form.form_id, form_slug: form.form_slug),
           params: { start_new_form_input: { start_new_form: start_new_form_choice } }
    end

    let(:start_new_form_choice) { "yes" }

    context "when the user is not signed in to GOV.UK One Login" do
      before { post_submit_not_found }

      it "redirects to the sign-in interstitial" do
        expect(response).to redirect_to(continue_saved_form_path(form.form_id, form.form_slug, mode:))
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
          answers: { form.form_id.to_s => { "1" => { "text" => "an answer" } } },
        }
      end

      context "when the user chooses to start a new form" do
        before { post_submit_not_found }

        it "redirects to the first question" do
          expect(response).to redirect_to(form_step_path(mode:, form_id: form.form_id, form_slug: form.form_slug, step_slug: 1))
        end

        it "clears the answers from the session" do
          expect(store.dig(:answers, form.form_id.to_s)).to be_blank
        end
      end

      context "when the user chooses to sign in with a different GOV.UK One Login" do
        let(:start_new_form_choice) { "no" }
        let(:auth_service) { AuthService.new(store) }

        before do
          allow(AuthService).to receive(:new).and_return(auth_service)
          allow(auth_service).to receive(:logout_redirect_uri).and_return("http://example.com/one-login-mock/logout")
          post_submit_not_found
        end

        it "redirects to the GOV.UK One Login logout endpoint" do
          expect(response).to redirect_to("http://example.com/one-login-mock/logout")
        end

        it "asks GOV.UK One Login to send the user back to the logged out route" do
          expect(auth_service)
            .to have_received(:logout_redirect_uri)
            .with a_string_starting_with(omniauth_logged_out_url)
        end

        it "stores the sign in again return params in the session" do
          expect(store["return_from_one_login"]).to eq({
            "return_to" => "sign_in_again_to_continue_saved_form",
            "last_form_id" => form.form_id,
            "last_form_slug" => form.form_slug,
            "last_mode" => mode,
            "last_locale" => nil,
          })
        end
      end

      context "when the user does not choose an option" do
        let(:start_new_form_choice) { nil }

        before { post_submit_not_found }

        it "re-renders the not found page with an error" do
          expect(response).to have_http_status(:unprocessable_content)
          expect(response).to render_template(:not_found)
          expect(response.body).to include(I18n.t("activemodel.errors.models.start_new_form_input.attributes.start_new_form.blank"))
        end

        it "shows the email address the user is signed in with" do
          expect(response.body).to include("<strong>test@example.com</strong>")
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
          create(:incomplete_submission, user_id: "user-sub-123", form_id: form.form_id, answers: { "1" => { "text" => "a saved answer" } }, mode:)

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
