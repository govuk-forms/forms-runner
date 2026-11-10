class RemoveSubmissionReferenceFromIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def change
    remove_column :incomplete_submissions, :submission_reference, :string
  end
end
