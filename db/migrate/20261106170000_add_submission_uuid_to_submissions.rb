class AddSubmissionUuidToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :submission_uuid, :string
    add_index :submissions, :submission_uuid, unique: true
  end
end
