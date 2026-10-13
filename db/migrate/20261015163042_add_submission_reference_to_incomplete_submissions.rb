class AddSubmissionReferenceToIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :incomplete_submissions, :submission_reference, :string
  end
end
