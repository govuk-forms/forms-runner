class StartNewFormInput
  include ActiveModel::Model

  attr_accessor :start_new_form

  OPTIONS = %w[yes no].freeze

  validates :start_new_form, presence: true, inclusion: { in: OPTIONS }

  def start_new_form?
    start_new_form == "yes"
  end
end
