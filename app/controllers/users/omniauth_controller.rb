module Users
  class OmniauthController < ApplicationController
    class OmniAuthLoggedInDataMissingError < StandardError; end

    rescue_from Store::ReturnFromOneLoginStore::MissingReturnParamsError do
      Rails.logger.warn("Missing return params in session for One Login callback")
      redirect_to error_404_path
    end

    def callback
      email = request.env.dig("omniauth.auth", "info", "email")
      if email.blank?
        raise OmniAuthLoggedInDataMissingError, "Email is missing in OmniAuth auth hash"
      end

      return_from_one_login_store = Store::ReturnFromOneLoginStore.new(session)
      form_id = return_from_one_login_store.form_id
      path_params = return_from_one_login_store.get_path_params

      Store::ConfirmationDetailsStore.new(session, form_id).save_copy_of_answers_email_address(email)

      redirect_to check_your_answers_path(**path_params)
    end
  end
end
