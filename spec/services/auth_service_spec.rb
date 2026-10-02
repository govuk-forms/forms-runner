require "rails_helper"

RSpec.describe AuthService do
  subject(:auth_service) { described_class.new(store) }

  let(:end_session_endpoint) { "http://example.com/one-login-mock/logout" }
  let(:store) { {}.with_indifferent_access }
  let(:token) { Faker::Alphanumeric.alphanumeric }

  before do
    idp_configuration = instance_double(OmniAuth::GovukOneLogin::IdpConfiguration, end_session_endpoint:)
    allow(Rails.application.config.x).to receive(:one_login).and_return(double(idp_configuration:))
  end

  describe "#store_auth_details" do
    let(:email) { "test@example.com" }
    let(:sub) { Faker::Alphanumeric.alphanumeric }
    let(:authenticated_at) { Time.current.to_i }
    let(:id_token) { JWT.encode({ iat: authenticated_at }, nil, "none") }
    let(:auth_hash) do
      {
        uid: sub,
        info: { email: },
        credentials: { id_token: },
      }.with_indifferent_access
    end

    context "when the return from one login params are not set on the session" do
      it "raises a MissingReturnParamsError" do
        expect { auth_service.store_auth_details({}) }
          .to raise_error(Store::ReturnFromOneLoginStore::MissingReturnParamsError)
      end
    end

    context "when the return from one login params are set on the session" do
      let(:form_id) { 42 }
      let(:store) do
        {
          "return_from_one_login" => {
            "last_form_id" => form_id,
          },
        }.with_indifferent_access
      end

      context "when the auth hash is empty" do
        let(:auth_hash) { {}.with_indifferent_access }

        it "raises a DataMissingError" do
          expect { auth_service.store_auth_details(auth_hash) }
            .to raise_error(AuthService::DataMissingError, "Auth hash is missing on request")
        end
      end

      context "when the email is missing from the auth hash" do
        let(:auth_hash) { { credentials: { id_token: } }.with_indifferent_access }

        it "raises a DataMissingError" do
          expect { auth_service.store_auth_details(auth_hash) }
            .to raise_error(AuthService::DataMissingError, "Email is missing in OmniAuth auth hash")
        end
      end

      context "when the token is missing from the auth hash" do
        let(:auth_hash) { { info: { email: } }.with_indifferent_access }

        it "raises a DataMissingError" do
          expect { auth_service.store_auth_details(auth_hash) }
            .to raise_error(AuthService::DataMissingError, "Token is missing in OmniAuth auth hash")
        end
      end

      context "when the sub is missing from the auth hash" do
        let(:auth_hash) { { info: { email: }, credentials: { id_token: } }.with_indifferent_access }

        it "raises a DataMissingError" do
          expect { auth_service.store_auth_details(auth_hash) }
            .to raise_error(AuthService::DataMissingError, "Sub is missing in OmniAuth auth hash")
        end
      end

      context "when the id_token has no iat claim" do
        let(:id_token) { JWT.encode({}, nil, "none") }

        it "raises a DataMissingError" do
          expect { auth_service.store_auth_details(auth_hash) }
            .to raise_error(AuthService::DataMissingError, "Token issued-at is missing in OmniAuth auth hash")
        end
      end

      context "when the id_token cannot be decoded" do
        let(:id_token) { "not-a-jwt" }

        it "raises a DataMissingError" do
          expect { auth_service.store_auth_details(auth_hash) }
            .to raise_error(AuthService::DataMissingError, "Token issued-at is invalid in OmniAuth auth hash")
        end
      end

      context "when the auth hash is valid" do
        it "stores the email on the session" do
          auth_service.store_auth_details(auth_hash)
          expect(store.dig("confirmation_details", form_id.to_s, "copy_of_answers_email_address")).to eq email
        end

        it "stores the token on the session" do
          auth_service.store_auth_details(auth_hash)
          expect(store["auth"]["token"]).to eq id_token
        end

        it "stores the sub on the session" do
          auth_service.store_auth_details(auth_hash)
          expect(store["auth"]["sub"]).to eq sub
        end

        it "stores the authenticated_at on the session" do
          auth_service.store_auth_details(auth_hash)
          expect(store["auth"]["authenticated_at"]).to eq authenticated_at
        end
      end
    end
  end

  describe "#logout_redirect_uri" do
    let(:store) do
      {
        auth: { token: },
      }.with_indifferent_access
    end
    let(:post_logout_redirect_uri) { "https://example.com/some-path?with=params" }

    it "returns a logout request with the expected One Login URI" do
      logout_redirect_uri = auth_service.logout_redirect_uri(post_logout_redirect_uri)
      expect(logout_redirect_uri).to start_with(end_session_endpoint)
    end

    it "strips query params from the post_logout_redirect_uri" do
      logout_redirect_uri = auth_service.logout_redirect_uri(post_logout_redirect_uri)
      parsed_uri = URI.parse(logout_redirect_uri)
      query = Rack::Utils.parse_query(parsed_uri.query)
      expect(query).to include("post_logout_redirect_uri" => "https://example.com/some-path",
                               "id_token_hint" => token)
    end
  end

  describe "#clear_auth_session" do
    let(:store) do
      {
        auth: { token: },
      }.with_indifferent_access
    end

    it "clears the session" do
      auth_service.clear_auth_session
      expect(store["auth"]).to be_nil
    end
  end

  describe "#current_one_login_session" do
    context "when not logged in" do
      it "returns nil" do
        expect(auth_service.current_one_login_session).to be_nil
      end
    end

    context "when logged in" do
      let(:sub) { Faker::Alphanumeric.alphanumeric }
      let(:email) { "test@example.com" }
      let(:store) do
        {
          auth: {
            sub:,
            email:,
            token:,
            authenticated_at: Time.current.to_i,
          },
        }.with_indifferent_access
      end

      it "returns the sub and email of the current session" do
        session = auth_service.current_one_login_session
        expect(session.sub).to eq(sub)
        expect(session.email).to eq(email)
      end
    end
  end

  describe "delegated readers" do
    let(:sub) { Faker::Alphanumeric.alphanumeric }
    let(:email) { "test@example.com" }
    let(:store) do
      {
        auth: { sub:, email:, authenticated_at: Time.current.to_i },
      }.with_indifferent_access
    end

    it "delegates #sub to the auth store" do
      expect(auth_service.sub).to eq(sub)
    end

    it "delegates #email to the auth store" do
      expect(auth_service.email).to eq(email)
    end
  end
end
