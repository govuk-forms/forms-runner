require "rails_helper"

RSpec.describe "omniauth initializer" do
  let(:initializer_path) { Rails.root.join("config/initializers/omniauth.rb") }

  let(:one_login_settings) do
    double(
      private_key: private_key_setting,
      client_id: "test-client-id",
      base_url: "https://oidc.integration.account.gov.uk",
    )
  end

  before do
    allow(Settings).to receive(:govuk_one_login).and_return(one_login_settings)
    allow(Rails.application.config.middleware).to receive(:use)
    allow(OmniAuth::GovukOneLogin::IdpConfiguration).to receive(:new).and_return(instance_double(OmniAuth::GovukOneLogin::IdpConfiguration))
  end

  around do |example|
    original_public_key_jwk = Rails.application.config.x.one_login.public_key_jwk
    original_idp_configuration = Rails.application.config.x.one_login.idp_configuration
    example.run
  ensure
    Rails.application.config.x.one_login.public_key_jwk = original_public_key_jwk
    Rails.application.config.x.one_login.idp_configuration = original_idp_configuration
  end

  context "when the private key is present" do
    let(:rsa_private_key) { OpenSSL::PKey::RSA.generate(2048) }
    let(:private_key_setting) { Base64.encode64(rsa_private_key.to_pem) }

    before { load initializer_path }

    it "sets Rails.application.config.x.one_login.public_key_jwk" do
      expect(Rails.application.config.x.one_login.public_key_jwk).to be_a(JWT::JWK::RSA)
    end

    it "sets the JWK use to 'sig'" do
      expect(Rails.application.config.x.one_login.public_key_jwk[:use]).to eq("sig")
    end

    it "sets the JWK kid" do
      expect(Rails.application.config.x.one_login.public_key_jwk.kid).to be_a(String)
    end
  end

  context "when the private key is absent" do
    let(:private_key_setting) { nil }

    before do
      Rails.application.config.x.one_login.public_key_jwk = nil
      load initializer_path
    end

    it "does not set Rails.application.config.x.one_login.public_key_jwk" do
      expect(Rails.application.config.x.one_login.public_key_jwk).to be_nil
    end
  end
end
