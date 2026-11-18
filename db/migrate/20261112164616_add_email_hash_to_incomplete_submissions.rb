class AddEmailHashToIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :incomplete_submissions, :email_hash, :string, comment: "HMAC-SHA256 of the user's GOV.UK One Login email address, used to find their incomplete submissions"
    add_index :incomplete_submissions, :email_hash
  end
end
