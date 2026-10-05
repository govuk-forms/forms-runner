class AuthService
  class DataMissingError < StandardError; end

  attr_reader :auth_store, :return_from_one_login_store

  def initialize(store)
    @store = store
    @return_from_one_login_store = Store::ReturnFromOneLoginStore.new(store)
    @auth_store = Store::AuthStore.new(store)
  end

  delegate :logged_in?, to: :auth_store
  delegate :store_return_params, :form_path_params, to: :return_from_one_login_store
  delegate :sub, to: :auth_store
  delegate :email, to: :auth_store

  def store_auth_details(auth_hash)
    form_id = @return_from_one_login_store.form_id

    raise DataMissingError, "Auth hash is missing on request" if auth_hash.blank?

    email = auth_hash.dig("info", "email")
    raise DataMissingError, "Email is missing in OmniAuth auth hash" if email.blank?

    token = auth_hash.dig("credentials", "id_token")
    raise DataMissingError, "Token is missing in OmniAuth auth hash" if token.blank?

    sub = auth_hash["uid"]
    raise DataMissingError, "Sub is missing in OmniAuth auth hash" if sub.blank?

    begin
      authenticated_at = JWT.decode(token, nil, false).first["iat"]
    rescue JWT::DecodeError
      raise DataMissingError, "Token issued-at is invalid in OmniAuth auth hash"
    end
    raise DataMissingError, "Token issued-at is missing in OmniAuth auth hash" if authenticated_at.blank?

    @auth_store.store_session(sub:, email:, token:, authenticated_at:)
    Store::ConfirmationDetailsStore.new(@store, form_id).save_copy_of_answers_email_address(email)
  end

  def current_one_login_session
    return nil unless logged_in?

    Data.define(:sub, :email).new(sub:, email:)
  end

  def logout_redirect_uri(post_logout_redirect_uri)
    token = @auth_store.get_token
    logout_request = logout_utility.build_request(
      id_token_hint: token,
      post_logout_redirect_uri: url_without_params(post_logout_redirect_uri),
    )
    logout_request.redirect_uri
  end

  def clear_auth_session
    @auth_store.clear
  end

private

  def logout_utility
    @logout_utility ||= OmniAuth::GovukOneLogin::LogoutUtility.new(
      idp_configuration: Rails.application.config.x.one_login.idp_configuration,
    )
  end

  def url_without_params(url)
    url = URI.parse(url)
    url.query = nil
    url.to_s
  end
end
