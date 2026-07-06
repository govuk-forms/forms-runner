class OneLoginJwksController < ApplicationController
  def show
    jwk = Rails.application.config.x.one_login.public_key_jwk
    render json: JWT::JWK::Set.new(jwk).export
  end
end
