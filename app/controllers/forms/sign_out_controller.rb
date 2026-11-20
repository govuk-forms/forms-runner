module Forms
  class SignOutController < BaseController
    def create
      return head :unauthorized unless auth_service.logged_in?

      auth_service.store_return_params(
        form: current_context.form,
        mode:,
        locale: locale_param,
        return_to: Store::ReturnFromOneLoginStore::RETURN_TO_VALUES[:signed_out],
      )

      redirect_to auth_service.logout_redirect_uri(omniauth_logged_out_url), allow_other_host: true
    end
  end
end
