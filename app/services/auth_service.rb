class AuthService
  def logout_request(token, post_logout_redirect_uri)
    logout_utility.build_request(
      id_token_hint: token,
      post_logout_redirect_uri: url_without_params(post_logout_redirect_uri),
    )
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
