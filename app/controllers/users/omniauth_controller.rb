module Users
  class OmniauthController < ApplicationController
    class FailureError < StandardError; end

    rescue_from AuthService::DataMissingError, FailureError do |exception|
      CurrentRequestLoggingAttributes.rescued_exception = [exception.class.name, exception.message]
      Sentry.capture_exception(exception)

      link_url = copy_of_answers_path(**auth_service.form_path_params)
      render "errors/auth_error", locals: { link_url: }, status: :bad_request
    rescue Store::ReturnFromOneLoginStore::MissingReturnParamsError
      render "errors/return_from_one_login_session_missing", status: :bad_request
    end

    def callback
      auth_hash = request.env["omniauth.auth"]
      auth_service.store_auth_details(auth_hash)

      redirect_to check_your_answers_path(**auth_service.form_path_params)
    rescue Store::ReturnFromOneLoginStore::MissingReturnParamsError => e
      CurrentRequestLoggingAttributes.rescued_exception = [e.class.name, e.message]
      render "errors/return_from_one_login_session_missing", status: :bad_request
    end

    def failure
      error = request.env["omniauth.error"]
      raise FailureError, error
    end

    def logged_out
      auth_service.clear_auth_session

      path_params = auth_service.form_path_params
      redirect_to form_submitted_path(**path_params)
    rescue Store::ReturnFromOneLoginStore::MissingReturnParamsError => e
      CurrentRequestLoggingAttributes.rescued_exception = [e.class.name, e.message]
      redirect_to :unknown_form_submitted
    end
  end
end
