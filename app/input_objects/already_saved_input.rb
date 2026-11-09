class AlreadySavedInput
  include ActiveModel::Model

  attr_accessor :already_saved

  OPTIONS = %w[overwrite keep_saved].freeze

  validates :already_saved, presence: true, inclusion: { in: OPTIONS }

  def overwrite?
    already_saved == "overwrite"
  end

  def keep_saved?
    already_saved == "keep_saved"
  end
end
