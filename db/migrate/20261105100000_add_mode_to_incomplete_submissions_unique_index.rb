class AddModeToIncompleteSubmissionsUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :incomplete_submissions, %i[user_id form_id], unique: true
    add_index :incomplete_submissions, %i[user_id form_id mode], unique: true
  end
end
