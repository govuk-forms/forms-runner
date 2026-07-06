class CopyOfAnswersInput
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :copy_of_answers

  RADIO_OPTIONS = { yes: "yes", no: "no" }.freeze

  validates :copy_of_answers, presence: true, inclusion: { in: RADIO_OPTIONS.values }

  def wants_copy?
    copy_of_answers == RADIO_OPTIONS[:yes]
  end

  def values
    RADIO_OPTIONS.keys
  end
end
