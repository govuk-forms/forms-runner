class AlreadySavedSignOutInput < AlreadySavedInput
  def options
    %w[overwrite keep_saved sign_out_without_saving].freeze
  end

  def sign_out_without_saving?
    already_saved == "sign_out_without_saving"
  end
end
