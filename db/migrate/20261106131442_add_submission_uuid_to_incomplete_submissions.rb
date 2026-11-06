class AddSubmissionUuidToIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def up
    add_column :incomplete_submissions, :submission_uuid, :string

    # Backfill existing records. gen_random_uuid() is evaluated per row.
    execute <<~SQL
      UPDATE incomplete_submissions
      SET submission_uuid = gen_random_uuid()::text
    SQL

    add_index :incomplete_submissions, :submission_uuid, unique: true
  end

  def down
    remove_index :incomplete_submissions, :submission_uuid
    remove_column :incomplete_submissions, :submission_uuid
  end
end
