class AddModeToIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :incomplete_submissions, :mode, :string
  end
end
