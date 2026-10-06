class SavedAnswer < ApplicationRecord
  encrypts :answers
  validates :user_id, presence: true
  validates :form_id, presence: true
end
