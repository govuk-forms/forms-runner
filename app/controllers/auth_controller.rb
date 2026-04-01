class AuthController < ApplicationController
  def callback
    # We come here after one login
    # We will need to restore, form_id, mode and form_slug, which we should have saved before sending
    if session["return_to"].present?

      # We need to do something to get the user's email here.
      #
      # We then need to set the email in the session somewhere
      session["one_login_email"] = "example@example.org"
      redirect_to session["return_to"]
    end
  end
end
