OmniAuth.config.logger = Rails.logger

private_key_pem = Settings.govuk_one_login.private_key
if private_key_pem
  # decode the private key from base64
  private_key_pem = Base64.decode64(private_key_pem)
  private_key_pem = private_key_pem.gsub('\n', "\n")

  private_key = OpenSSL::PKey::RSA.new(private_key_pem)
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :govuk_one_login, {
    name: :govuk_one_login,
    client_id: Settings.govuk_one_login.client_id,
    idp_base_url: Settings.govuk_one_login.base_url,
    private_key: private_key,
    redirect_uri: "/auth/govuk_one_login/callback",
    private_key_kid: "", # TODO: we'll need to set this when we switch to using a JWKS endpoint
    signing_algorithm: "ES256",
    scope: "openid email",
    ui_locales: "en cy",
    vtr: ["Cl.Cm"],
    pkce: false,
    userinfo_claims: [],
  }
end
