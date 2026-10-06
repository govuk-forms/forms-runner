class AddUniqueIndexToIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_index :incomplete_submissions, %i[user_id form_id], unique: true
  end
end
