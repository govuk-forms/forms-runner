module Users
  class OmniauthController < ApplicationController
    class OmniAuthFailure < StandardError; end

    def callback
      auth_hash = request.env["omniauth.auth"]
      auth_service.store_auth_details(auth_hash)

      path_params = auth_service.form_path_params

      redirect_to check_your_answers_path(**path_params)
    rescue Store::ReturnFromOneLoginStore::MissingReturnParamsError
      Rails.logger.warn("Missing return params in session for One Login callback")
      redirect_to error_404_path
    end

    def failure
      error = request.env["omniauth.error"]
      raise OmniAuthFailure, error
    end

    def logged_out
      auth_service.clear_auth_session

      path_params = auth_service.form_path_params
      redirect_to form_submitted_path(**path_params)
    end
  end
end
