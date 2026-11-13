class AlreadySavedInput
  include ActiveModel::Model

  attr_accessor :already_saved

  validates :already_saved, presence: true, inclusion: { in: :options }

  def options
    %w[overwrite keep_saved].freeze
  end

  def overwrite?
    already_saved == "overwrite"
  end

  def keep_saved?
    already_saved == "keep_saved"
  end
end
