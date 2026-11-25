class ContinueWithOneLoginInput
  include ActiveModel::Model

  attr_accessor :continue_with_this_one_login

  OPTIONS = %w[yes no].freeze

  validates :continue_with_this_one_login, presence: true, inclusion: { in: OPTIONS }

  def continue?
    continue_with_this_one_login == "yes"
  end
end
