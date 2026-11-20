require "rails_helper"

RSpec.describe Forms::SignOutController do
  let(:form) { build :form_document, :with_support, steps:, start_page: 1, available_languages: %w[en cy] }
  let(:steps) { [build(:question_step, :with_text_settings, id: 1)] }
  let(:mode) { "preview-draft" }
  let(:locale) { nil }
  let(:authenticated_at) { Time.current.to_i }
  let(:auth_session) { { "token" => "id-token", "authenticated_at" => authenticated_at } }

  let(:req_headers) { { "Accept" => "application/json" } }
  let(:store) { { "auth" => auth_session }.compact }
  let(:auth_service) { AuthService.new(store) }

  before do
    language_suffix = "?language=#{locale}" if locale == :cy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/api/v2/forms/#{form.form_id}/draft#{language_suffix}", req_headers, form.to_json, 200
    end

    allow(Flow::Context).to receive(:new).and_wrap_original do |original_method, *args|
      original_method.call(form: args[0][:form], form_document: args[0][:form_document], store:)
    end
    allow(auth_service).to receive(:logout_redirect_uri).and_return("http://example.com/one-login-mock/logout")
    allow(AuthService).to receive(:new).and_return auth_service

    post sign_out_path(mode:, form_id: form.form_id, form_slug: form.form_slug, locale:)
  end

  describe "POST #create" do
    context "when there is no One Login token in the session" do
      let(:auth_session) { nil }

      it "redirects to the GOV.UK One Login signed out page" do
        expect(response).to redirect_to(GovukOneLogin.signed_out_url)
      end

      it "does not redirect to the GOV.UK One Login logout endpoint" do
        expect(auth_service).not_to have_received(:logout_redirect_uri)
      end

      context "when the locale is not the default locale" do
        let(:locale) { :cy }

        it "redirects to the GOV.UK One Login signed out page in that language" do
          expect(response).to redirect_to("#{GovukOneLogin.signed_out_url}?lng=cy")
        end
      end
    end

    context "when the One Login session has expired but the token is still in the session" do
      let(:authenticated_at) { 0 }

      it "redirects to the GOV.UK One Login logout endpoint" do
        expect(response).to redirect_to("http://example.com/one-login-mock/logout")
      end
    end

    context "when the user is logged in" do
      it "redirects to the GOV.UK One Login logout endpoint" do
        expect(response).to redirect_to("http://example.com/one-login-mock/logout")
      end

      it "asks GOV.UK One Login to send the user back to the logged out route" do
        expect(auth_service)
          .to have_received(:logout_redirect_uri)
          .with a_string_starting_with(omniauth_logged_out_url)
      end

      it "stores the return from one login params in the session" do
        expect(store["return_from_one_login"]).to eq({
          "return_to" => "signed_out",
          "last_form_id" => form.form_id,
          "last_form_slug" => form.form_slug,
          "last_mode" => mode,
          "last_locale" => nil,
        })
      end

      context "when the locale is not the default locale" do
        let(:locale) { :cy }

        it "stores the locale in the session" do
          expect(store["return_from_one_login"]["last_locale"]).to eq "cy"
        end
      end
    end
  end
end
