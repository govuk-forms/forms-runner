require "rails_helper"
require "base64"

RSpec.describe OneLoginJwksController, type: :request do
  describe "GET #show" do
    before do
      public_key = OpenSSL::PKey::RSA.generate(2048).public_key
      public_key_jwk = JWT::JWK.new(public_key, use: "sig")

      one_login_config = ActiveSupport::OrderedOptions.new
      one_login_config.public_key_jwk = public_key_jwk

      allow(Rails.application.config.x).to receive(:one_login).and_return(one_login_config)
    end

    it "returns the JWKS JSON" do
      get one_login_jwks_path

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")
      expect(response.parsed_body).to match({
        "keys" => [
          {
            "e" => "AQAB",
            "kty" => "RSA",
            "use" => "sig",
            "kid" => a_kind_of(String),
            "n" => a_kind_of(String),
          },
        ],
      })
    end
  end
end
