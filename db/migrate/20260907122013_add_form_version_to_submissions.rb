class AddFormVersionToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :form_version, :integer
  end
end
