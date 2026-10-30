require "rails_helper"

RSpec.describe Users::OmniauthController, type: :request do
  let(:return_to) { "copy_of_answers" }
  let(:form_id) { 42 }
  let(:form_slug) { "test-form" }
  let(:mode) { "preview-draft" }
  let(:locale) { "cy" }
  let(:return_from_one_login_session) do
    {
      "return_to" => return_to,
      "last_form_id" => form_id,
      "last_form_slug" => form_slug,
      "last_mode" => mode,
      "last_locale" => locale,
    }
  end
  let(:store) { {}.with_indifferent_access }

  before do
    allow(AuthService).to receive(:new).and_wrap_original do |original_method, *_args|
      original_method.call(store)
    end
  end

  describe "POST /auth/govuk_one_login", :capture_logging do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:default] = nil
    end

    let(:redirect_log_line) { log_lines.find { |line| line["event"] == "redirect_to_one_login" } }

    it "logs a line including the session_id_hash" do
      post "/auth/govuk_one_login"

      expect(redirect_log_line).to include(
        "request_id" => be_present,
        "session_id_hash" => match(/\A\h{64}\z/),
      )
    end

    context "when the return from One Login params are in the session" do
      before do
        return_store = instance_double(Store::ReturnFromOneLoginStore, form_id:)
        allow(Store::ReturnFromOneLoginStore).to receive(:new).and_return(return_store)
      end

      it "logs the form_id" do
        post "/auth/govuk_one_login"

        expect(redirect_log_line).to include("form_id" => form_id)
      end
    end

    context "when the return from One Login params are not in the session" do
      it "logs the line without a form_id" do
        post "/auth/govuk_one_login"

        expect(redirect_log_line).to be_present
        expect(redirect_log_line).not_to have_key("form_id")
      end
    end
  end

  describe "GET #callback", :capture_logging do
    let(:store) do
      {
        "return_from_one_login" => return_from_one_login_session,
      }.with_indifferent_access
    end

    let(:email) { "test@example.com" }
    let(:authenticated_at) { Time.current.to_i }
    let(:id_token) { JWT.encode({ iat: authenticated_at }, nil, "none") }
    let(:auth_hash) do
      {
        provider: :govuk_one_login,
        uid: "123",
        info: {
          email:,
        },
        credentials: {
          id_token:,
        },
      }.with_indifferent_access
    end

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:default] = auth_hash
      allow(Sentry).to receive(:capture_exception)

      get omniauth_callback_path
    end

    context "when the auth details are present on the request and the user has a valid session" do
      it "redirects to the check your answers page" do
        expect(response).to redirect_to(check_your_answers_path(form_id:, form_slug:, mode:, locale:))
      end

      it "logs the logged_in_with_one_login event with the form_id" do
        log_line = log_lines.find { |line| line["event"] == "logged_in_with_one_login" }
        expect(log_line).to include("form_id" => form_id)
      end

      it "stores the user's email address on the session" do
        expect(store.dig("confirmation_details", form_id.to_s, "copy_of_answers_email_address")).to eq email
      end

      it "stores the token on the session" do
        expect(store["auth"]["token"]).to eq id_token
      end

      it "stores the sub on the session" do
        expect(store["auth"]["sub"]).to eq "123"
      end

      it "stores the authenticated_at on the session" do
        expect(store["auth"]["authenticated_at"]).to eq authenticated_at
      end
    end

    context "when the session says to return to save progress" do
      let(:return_from_one_login_session) do
        {
          "last_form_id" => form_id,
          "last_form_slug" => form_slug,
          "last_mode" => mode,
          "last_locale" => locale,
          "return_to" => "save_and_return",
        }
      end

      it "redirects to the save progress after sign in action" do
        expect(response).to redirect_to(save_progress_after_sign_in_path(form_id:, form_slug:, mode:, locale:))
      end
    end

    context "when the session says to return to copy of answers" do
      let(:return_from_one_login_session) do
        {
          "last_form_id" => form_id,
          "last_form_slug" => form_slug,
          "last_mode" => mode,
          "last_locale" => locale,
          "return_to" => "copy_of_answers",
        }
      end

      it "redirects to the check your answers page" do
        expect(response).to redirect_to(check_your_answers_path(form_id:, form_slug:, mode:, locale:))
      end
    end

    context "when data is missing on the auth details on the request" do
      let(:auth_hash) { {} }

      welsh = I18n.t("errors.auth_error.title", locale: :cy)
      english = I18n.t("errors.auth_error.title", locale: :en)

      it "renders the auth error page" do
        expect(response).to have_http_status(400)
        expect(response).to render_template("errors/auth_error")
        expect(response.body).to include("href=\"#{copy_of_answers_path(mode:, form_id:, form_slug:, locale:)}\"")
      end

      it "logs the error" do
        expect(log_lines.last["rescued_exception"]).to eq(["AuthService::DataMissingError", "Auth hash is missing on request"])
      end

      it "sends the error to Sentry" do
        expect(Sentry).to have_received(:capture_exception).with(
          an_instance_of(AuthService::DataMissingError),
        )
      end

      context "when the form is being used in welsh" do
        let(:locale) { "cy" }

        it "renders the auth error page in welsh" do
          expect(response).to have_http_status(400)
          expect(response).to render_template("errors/auth_error")
          expect(response.body).to include(welsh)
          expect(response.body).not_to include(english)
        end
      end

      context "when the locale in form_path_params is nil" do
        let(:locale) { nil }

        it "renders the auth error page in english" do
          expect(response).to have_http_status(400)
          expect(response).to render_template("errors/auth_error")
          expect(response.body).to include(english)
          expect(response.body).not_to include(welsh)
        end
      end
    end

    context "when the return from one login params are not present on the session" do
      let(:store) { {} }

      it "renders the return from one login session missing page" do
        expect(response).to have_http_status(400)
        expect(response).to render_template("errors/return_from_one_login_session_missing")
      end

      it "logs the error" do
        expect(log_lines.last["rescued_exception"]).to eq(["Store::ReturnFromOneLoginStore::MissingReturnParamsError", "Return from One Login parameters are missing from the session"])
      end
    end
  end

  describe "GET #failure", :capture_logging do
    let(:error) { StandardError.new("An error") }

    before do
      allow(Sentry).to receive(:capture_exception)
      get omniauth_failure_path, env: { "omniauth.error" => error }
    end

    context "when the return from one login params are present on the session" do
      let(:store) do
        {
          "return_from_one_login" => return_from_one_login_session,
        }.with_indifferent_access
      end

      it "renders the auth error page" do
        expect(response).to have_http_status(400)
        expect(response).to render_template("errors/auth_error")
        expect(response.body).to include("href=\"#{copy_of_answers_path(mode:, form_id:, form_slug:, locale:)}\"")
      end

      it "logs the error" do
        expect(log_lines.last["rescued_exception"]).to eq(["Users::OmniauthController::FailureError", error.message])
      end

      it "sends the error to Sentry" do
        expect(Sentry).to have_received(:capture_exception).with(
          an_instance_of(Users::OmniauthController::FailureError),
        )
      end

      context "and the error is a CallbackStateMismatchError" do
        let(:error) { OmniAuth::GovukOneLogin::CallbackStateMismatchError.new "Callback state mismatch" }

        it "logs the error" do
          expect(log_lines.last["rescued_exception"]).to eq(["Users::OmniauthController::FailureError", error.message])
        end

        it "does not send the error to Sentry" do
          expect(Sentry).not_to have_received(:capture_exception)
        end
      end

      context "and the error is not an Exception" do
        let(:error) { "A message" }

        it "logs the error" do
          expect(log_lines.last["rescued_exception"]).to eq(["Users::OmniauthController::FailureError", error])
        end
      end
    end

    context "when the return from one login params are not present on the session" do
      it "renders the return from one login session missing page" do
        expect(response).to have_http_status(400)
        expect(response).to render_template("errors/return_from_one_login_session_missing")
      end

      it "logs the error" do
        expect(log_lines.last["rescued_exception"]).to eq(["Users::OmniauthController::FailureError", error.message])
      end

      it "sends the error to Sentry" do
        expect(Sentry).to have_received(:capture_exception).with(
          an_instance_of(Users::OmniauthController::FailureError),
        )
      end
    end
  end

  describe "POST #logout" do
    let(:auth_service) { AuthService.new(store) }

    context "when the user is not logged in" do
      before do
        allow(auth_service).to receive_messages(
          logged_in?: false,
        )

        allow(AuthService).to receive(:new).and_return auth_service
      end

      it "responds 401 unauthorized" do
        post omniauth_logout_path

        expect(response).to have_http_status :unauthorized
      end
    end

    context "when the user is logged in" do
      before do
        allow(auth_service).to receive_messages(
          logged_in?: true,
          logout_redirect_uri: "http://example.com/one-login-mock/logout",
        )

        allow(AuthService).to receive(:new).and_return auth_service
      end

      it "redirects to the GOV.UK One Login logout endpoint" do
        post omniauth_logout_path

        expect(response).to redirect_to("http://example.com/one-login-mock/logout")
      end

      it "asks GOV.UK One Login to send the user back to the logged out route" do
        post omniauth_logout_path

        expect(auth_service)
          .to have_received(:logout_redirect_uri)
          .with omniauth_logged_out_url
      end

      it "stores the return from one login params in the session" do
        post omniauth_logout_path

        expect(store["return_from_one_login"]).to eq({
          "return_to" => "signed_out",
          "last_locale" => nil,
        })
      end

      context "when the locale is the default locale" do
        it "does not store the locale in the session" do
          post omniauth_logout_path(locale: I18n.default_locale)

          expect(store["return_from_one_login"]["last_locale"]).to be_nil
        end
      end

      context "when the locale is not the default locale" do
        it "stores the locale in the session" do
          post omniauth_logout_path(locale: :cy)

          expect(store["return_from_one_login"]["last_locale"]).to eq "cy"
        end
      end
    end
  end

  describe "GET #logged_out", :capture_logging do
    let(:token) { Faker::Alphanumeric.alphanumeric }

    before do
      allow(AuthService).to receive(:new).and_wrap_original do |original_method, *_args|
        original_method.call(store)
      end
      get omniauth_logged_out_path
    end

    context "when the return from one login params are set on the session" do
      let(:store) do
        {
          "return_from_one_login" => return_from_one_login_session,
          "auth": { "token": token },
        }.with_indifferent_access
      end

      it "clears the auth details on the session" do
        expect(store).not_to have_key("auth")
      end

      context "when return_to is not set" do
        let(:return_from_one_login_session) do
          {
            "last_form_id" => form_id,
            "last_form_slug" => form_slug,
            "last_mode" => mode,
            "last_locale" => locale,
          }
        end

        it "redirects to the form submitted page" do
          expect(response).to redirect_to(form_submitted_path(form_id:, form_slug:, mode:, locale:))
        end
      end

      context "when the session says to return to copy of answers" do
        let(:return_to) { "copy_of_answers" }

        it "redirects to the form submitted page" do
          expect(response).to redirect_to(form_submitted_path(form_id:, form_slug:, mode:, locale:))
        end
      end

      context "when the session says to return to signed out page" do
        let(:return_to) { "signed_out" }

        it "redirects to the GOV.UK One Login signed out page" do
          expect(response).to redirect_to("http://example.com/one-login-mock/signed-out?lng=cy")
        end

        context "when the locale is nil" do
          let(:locale) { nil }

          it "redirects to the GOV.UK One Login signed out page in the default locale" do
            expect(response).to redirect_to("http://example.com/one-login-mock/signed-out")
          end
        end
      end
    end

    context "when the return from one login params are not set on the session" do
      let(:store) { {} }

      it "redirects to the unknown form submitted page" do
        expect(response).to redirect_to(:unknown_form_submitted)
      end

      it "logs the error" do
        expect(log_lines.last["rescued_exception"]).to eq(["Store::ReturnFromOneLoginStore::MissingReturnParamsError", "Return from One Login parameters are missing from the session"])
      end
    end
  end
end
