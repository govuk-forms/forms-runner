class CreateIncompleteSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :incomplete_submissions do |t|
      t.string :user_id, null: false, comment: "The 'sub' identifier from GOV.UK One Login"
      t.integer :form_id, null: false
      t.integer :form_version
      t.jsonb :answers
      t.timestamps
    end
  end
end
