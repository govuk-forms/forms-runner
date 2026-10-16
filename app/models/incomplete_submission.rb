class IncompleteSubmission < ApplicationRecord
  encrypts :answers
  validates :user_id, presence: true
  validates :form_id, presence: true, uniqueness: { scope: :user_id }
end
