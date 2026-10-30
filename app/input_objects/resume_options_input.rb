class ResumeOptionsInput
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :resume_options

  RADIO_OPTIONS = { start_new: "start_new", continue_saved: "continue_saved" }.freeze

  validates :resume_options, presence: true, inclusion: { in: RADIO_OPTIONS.values }

  def continue_saved?
    resume_options == RADIO_OPTIONS[:continue_saved]
  end

  def values
    RADIO_OPTIONS.keys
  end
end
