require "rails_helper"

RSpec.describe Users::OmniauthController, type: :request do
  describe "GET #callback" do
    let(:form_id) { 42 }
    let(:form_slug) { "test-form" }
    let(:mode) { "preview-draft" }
    let(:locale) { "cy" }
    let(:store) do
      {
        "return_from_one_login" => {
          "last_form_id" => form_id,
          "last_form_slug" => form_slug,
          "last_mode" => mode,
          "last_locale" => locale,
        },
      }.with_indifferent_access
    end

    let(:email) { "test@example.com" }
    let(:auth_hash) do
      {
        provider: :govuk_one_login,
        uid: "123",
        info: {
          email:,
        },
        credentials: {
          id_token: "id_token",
        },
      }.with_indifferent_access
    end

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:default] = auth_hash

      allow(Store::ReturnFromOneLoginStore).to receive(:new).and_wrap_original do |original_method, *_args|
        original_method.call(store)
      end
      allow(Store::ConfirmationDetailsStore).to receive(:new).and_wrap_original do |original_method, *args|
        original_method.call(store, args[1])
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
    end

    context "when the auth details are not present on the request" do
      let(:auth_hash) { {} }

      it "raises an OmniAuthLoggedInDataMissingError" do
        expect { get omniauth_callback_path }.to raise_error(Users::OmniauthController::OmniAuthLoggedInDataMissingError)
      end
    end

    context "when the email on the auth hash is blank" do
      let(:email) { "" }

      it "raises a OmniAuthLoggedInDataMissingError" do
        expect { get omniauth_callback_path }.to raise_error(Users::OmniauthController::OmniAuthLoggedInDataMissingError)
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
end
