require "rails_helper"

RSpec.describe Users::OmniauthController, type: :request do
  let(:form_id) { 42 }
  let(:form_slug) { "test-form" }
  let(:mode) { "preview-draft" }
  let(:locale) { "cy" }
  let(:return_from_one_login_session) do
    {
      "last_form_id" => form_id,
      "last_form_slug" => form_slug,
      "last_mode" => mode,
      "last_locale" => locale,
    }
  end

  describe "GET #callback" do
    let(:store) do
      {
        "return_from_one_login" => return_from_one_login_session,
      }.with_indifferent_access
    end

    let(:email) { "test@example.com" }
    let(:id_token) { Faker::Alphanumeric.alphanumeric }
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

      allow(AuthService).to receive(:new).and_wrap_original do |original_method, *_args|
        original_method.call(store)
      end
    end

    context "when the auth details are present on the request and the user has a valid session" do
      before do
        get omniauth_callback_path
      end

      it "redirects to the check your answers page" do
        expect(response).to redirect_to(check_your_answers_path(form_id:, form_slug:, mode:, locale:))
      end

      it "stores the user's email address on the session" do
        expect(store.dig("confirmation_details", form_id.to_s, "copy_of_answers_email_address")).to eq email
      end

      it "stores the token on the session" do
        expect(store["auth"]["token"]).to eq id_token
      end
    end

    context "when data is missing on the auth details on the request" do
      let(:auth_hash) { {} }

      it "raises an OmniAuthLoggedInDataMissingError" do
        expect { get omniauth_callback_path }.to raise_error(AuthService::DataMissingError)
      end
    end

    context "when the return from one login params are not present on the session" do
      let(:store) { {} }

      it "redirects to the 404 error page" do
        get omniauth_callback_path
        expect(response).to redirect_to(error_404_path)
      end
    end
  end

  describe "GET #failure" do
    let(:error_message) { "an error message" }

    it "raises a OmniAuthFailure error" do
      expect { get omniauth_failure_path, env: { "omniauth.error" => error_message } }.to raise_error(Users::OmniauthController::OmniAuthFailure, error_message)
    end
  end

  describe "GET #logged_out" do
    let(:token) { Faker::Alphanumeric.alphanumeric }

    before do
      allow(AuthService).to receive(:new).and_wrap_original do |original_method, *_args|
        original_method.call(store)
      end
    end

    context "when the return from one login params are set on the session" do
      let(:store) do
        {
          "return_from_one_login" => return_from_one_login_session,
          "auth": { "token": token },
        }.with_indifferent_access
      end

      before do
        get omniauth_logged_out_path
      end

      it "clears the auth details on the session" do
        expect(store).not_to have_key("auth")
      end

      it "redirects to the form submitted page" do
        expect(response).to redirect_to(form_submitted_path(form_id:, form_slug:, mode:, locale:))
      end
    end

    context "when the return from one login params are not set on the session" do
      let(:store) { {} }

      it "raises a Store::ReturnFromOneLoginStore::MissingReturnParamsError error" do
        expect { get omniauth_logged_out_path }.to raise_error Store::ReturnFromOneLoginStore::MissingReturnParamsError
      end
    end
  end
end
