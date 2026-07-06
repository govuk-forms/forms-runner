class UnknownFormSubmittedController < ApplicationController
  # This action is only visited when we've lost the user's session after they've been logged out from One Login
  def show; end
end
