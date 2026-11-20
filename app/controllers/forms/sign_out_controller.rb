require "govuk_one_login"

module Forms
  class SignOutController < BaseController
    def create
      return redirect_to one_login_signed_out_url, allow_other_host: true unless auth_service.token_present?

      auth_service.store_return_params(
        form: current_context.form,
        mode:,
        locale: locale_param,
        return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:signed_out],
      )

      redirect_to auth_service.logout_redirect_uri(omniauth_logged_out_url), allow_other_host: true
    end

  private

    def one_login_signed_out_url
      params = locale_param.present? ? "?lng=#{locale_param}" : ""
      "#{GovukOneLogin.signed_out_url}#{params}"
    end
  end
end
