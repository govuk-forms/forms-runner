module Users
  class OmniauthController < ApplicationController
    class OmniAuthLoggedInDataMissingError < StandardError; end

    class OmniAuthFailure < StandardError; end

    rescue_from Store::ReturnFromOneLoginStore::MissingReturnParamsError do
      Rails.logger.warn("Missing return params in session for One Login callback")
      redirect_to error_404_path
    end

    def callback
      auth_hash = request.env["omniauth.auth"]
      raise OmniAuthLoggedInDataMissingError, "Auth hash is missing on request" if auth_hash.blank?

      email = auth_hash.dig("info", "email")
      raise OmniAuthLoggedInDataMissingError, "Email is missing in OmniAuth auth hash" if email.blank?

      token = auth_hash.dig("credentials", "token")
      raise OmniAuthLoggedInDataMissingError, "Token is missing in OmniAuth auth hash" if token.blank?

      auth_store.store_token(token)

      return_from_one_login_store = Store::ReturnFromOneLoginStore.new(session)
      form_id = return_from_one_login_store.form_id
      path_params = return_from_one_login_store.get_path_params

      Store::ConfirmationDetailsStore.new(session, form_id).save_copy_of_answers_email_address(email)

      redirect_to check_your_answers_path(**path_params)
    end

    def failure
      error = request.env["omniauth.error"]
      raise OmniAuthFailure, error
    end
  end
end
